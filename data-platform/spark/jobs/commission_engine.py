"""
Commission Engine: Reads Gold dim/fact Iceberg tables, computes all 13 reports + KPI,
writes results to reporting.* Iceberg tables on s3://company-report/reporting/.

Usage:
  spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3 \
    commission_engine.py --date 2027-06-01
"""
import argparse
import os
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import (
    col, sum, count, countDistinct, when, lit, rank, desc,
    min_by, max_by, year, month, div0, coalesce, row_number
)
from pyspark.sql.window import Window
from functools import reduce

GOLD_BUCKET = "s3a://ssi-data/gold"
REPORT_BUCKET = "s3a://ssi-report"
REPORT_DB = "reporting"


def create_spark_session():
    """Spark session with Iceberg catalogs for Gold and Reporting."""
    return SparkSession.builder \
        .appName("CommissionEngine") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.gold", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.gold.type", "hadoop") \
        .config("spark.sql.catalog.gold.warehouse", GOLD_BUCKET) \
        .config("spark.sql.catalog.reporting", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.reporting.type", "hadoop") \
        .config("spark.sql.catalog.reporting.warehouse", f"{REPORT_BUCKET}/{REPORT_DB}") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", "")) \
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", "")) \
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("AWS_S3_ENDPOINT", "s3.amazonaws.com")) \
        .getOrCreate()


def write_report(df: DataFrame, table_name: str, date: str):
    """Write report DataFrame to reporting.* Iceberg table."""
    if df is None or df.rdd.isEmpty():
        print(f"[SKIP] No data for {table_name}")
        return
    target = f"reporting.{REPORT_DB}.{table_name}"
    print(f"[INFO] Writing {df.count()} rows to {target}")
    df.write \
      .mode("overwrite") \
      .format("iceberg") \
      .option("replace-where", f"_load_date = '{date}'") \
      .partitionBy("_load_date") \
      .saveAsTable(target)
    print(f"[DONE] {table_name}")


# ====== Report 1: Broker Commission Revenue ======
def compute_rpt_broker_commission_revenue(spark: SparkSession, date: str):
    df_trades = spark.read.table("gold.gold.int_all_trades").filter(col("trade_date") == date)
    df_broker = spark.read.table("gold.gold.dim_broker")
    df_fee = spark.read.table("gold.gold.dim_fee_schedule")

    result = df_trades.alias("t") \
        .join(df_broker.alias("b"), col("t.broker_code") == col("b.broker_code")) \
        .join(df_fee.alias("fs"),
              (col("fs.product_type") == col("t.product_type")) &
              (col("t.trade_date") >= col("fs.effective_from")) &
              ((col("fs.effective_to").isNull()) | (col("t.trade_date") <= col("fs.effective_to")))) \
        .groupBy("t.trade_date", "t.product_type", "t.broker_code", "b.broker_name",
                 "b.department_id", "b.department_name", "b.branch_id", "b.branch_name") \
        .agg(
            countDistinct("t.trade_id").alias("trade_count"),
            sum("t.amount").alias("trade_amount"),
            sum("t.fee_amount").alias("fee_revenue"),
            sum(col("t.fee_amount") * col("fs.commission_rate")).alias("broker_commission_amount")
        ) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 2: Department/Branch Ranking ======
def compute_rpt_department_branch_ranking(spark: SparkSession, date: str):
    rpt1 = spark.read.table(f"reporting.{REPORT_DB}.rpt_broker_commission_revenue") \
                .filter(col("_load_date") == date)
    result = rpt1.groupBy("department_id", "department_name", "branch_id", "branch_name") \
        .agg(
            sum("trade_amount").alias("total_trade_amount"),
            sum("fee_revenue").alias("total_fee_revenue"),
            countDistinct("broker_code").alias("broker_count"),
            sum("trade_count").alias("total_trade_count")
        ) \
        .withColumn("revenue_rank", rank().over(Window.orderBy(desc("total_fee_revenue")))) \
        .withColumn("trade_rank", rank().over(Window.orderBy(desc("total_trade_amount")))) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 3: Broker Performance ======
def compute_rpt_broker_performance(spark: SparkSession, date: str):
    trades = spark.read.table("gold.gold.fact_equity_trade").filter(col("trade_date") == date)
    broker = spark.read.table("gold.gold.dim_broker")
    # Customers per broker
    cust_counts = trades.groupBy("broker_code") \
        .agg(countDistinct("customer_code").alias("customer_count"),
             count("trade_id").alias("trade_count"),
             sum("amount").alias("total_amount"))
    result = broker.alias("b") \
        .join(cust_counts.alias("c"), col("b.broker_code") == col("c.broker_code"), "left") \
        .fillna(0) \
        .select(
            col("b.broker_code"), col("b.broker_name"), col("b.broker_type"),
            col("b.department_name"), col("b.branch_name"),
            col("c.customer_count"), col("c.trade_count"), col("c.total_amount"),
            (col("c.total_amount") / col("c.customer_count")).alias("amount_per_customer"),
            lit(date).alias("_load_date"))
    return result


# ====== Report 4: Trading Activity Summary ======
def compute_rpt_trading_activity_summary(spark: SparkSession, date: str):
    equity = spark.read.table("gold.gold.fact_equity_trade").filter(col("trade_date") == date)
    deriv = spark.read.table("gold.gold.fact_derivative_trade").filter(col("trade_date") == date)
    oef = spark.read.table("gold.gold.fact_oef_trade").filter(col("trade_date") == date)

    def agg_trades(df, product):
        return df.agg(
            count("trade_id").alias("trade_count"),
            countDistinct("customer_code").alias("customer_count"),
            sum("amount").alias("total_amount"),
            sum("fee_amount").alias("total_fee")
        ).withColumn("product_type", lit(product))

    eq_agg = agg_trades(equity, "EQUITY")
    de_agg = agg_trades(deriv, "DERIVATIVES")
    oef_agg = agg_trades(oef, "OEF")

    result = eq_agg.union(de_agg).union(oef_agg).withColumn("_load_date", lit(date))
    return result


# ====== Report 5: AUM Summary ======
def compute_rpt_aum_summary(spark: SparkSession, date: str):
    balance = spark.read.table("gold.gold.fact_account_balance_daily") \
                   .filter(col("balance_date") == date)
    account = spark.read.table("gold.gold.dim_account")
    broker = spark.read.table("gold.gold.dim_broker")
    cust_hist = spark.read.table("gold.gold.dim_customer_broker_history")

    # Join balance → account → broker via customer_broker_history at point in time
    result = balance.alias("b") \
        .join(account.alias("a"), (col("a.product_type") == col("b.product_type")) &
                                   (col("a.account_id") == col("b.account_id"))) \
        .join(cust_hist.alias("ch"),
              (col("ch.customer_code") == col("a.customer_code")) &
              (col("ch.is_current") == True)) \
        .join(broker.alias("br"), col("br.broker_code") == col("ch.broker_code")) \
        .groupBy("b.balance_date", "ch.broker_code", "br.broker_name",
                 "br.branch_id", "br.branch_name") \
        .agg(sum("b.total_asset_value").alias("total_aum"),
             countDistinct("a.customer_code").alias("customer_count")) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 6: Customer Acquisition Funnel ======
def compute_rpt_customer_acquisition_funnel(spark: SparkSession, date: str):
    ca = spark.read.table("gold.gold.dim_customer_acquisition").filter(col("acquisition_date") == date)
    trades = spark.read.table("gold.gold.int_all_trades").filter(col("trade_date") >= date)

    first_trade = trades.groupBy("customer_code") \
        .agg(min("trade_date").alias("first_trade_date"))

    result = ca.alias("ca") \
        .join(first_trade.alias("ft"), col("ft.customer_code") == col("ca.customer_code"), "left") \
        .groupBy(year("ca.acquisition_date").alias("acquisition_year"),
                 month("ca.acquisition_date").alias("acquisition_month"),
                 "ca.acquisition_channel", "ca.campaign_code", "ca.referral_broker_code") \
        .agg(countDistinct("ca.customer_code").alias("new_customer_count"),
             countDistinct(when(col("ft.first_trade_date").isNotNull(), col("ca.customer_code")))
                 .alias("converted_to_trading_count")) \
        .withColumn("conversion_rate",
                    col("converted_to_trading_count") / col("new_customer_count")) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 7: Customer Dormant ======
def compute_rpt_customer_dormant(spark: SparkSession, date: str):
    trades = spark.read.table("gold.gold.int_all_trades").filter(col("trade_date") <= date)
    cust = spark.read.table("gold.gold.dim_customer")

    last_trade = trades.groupBy("customer_code") \
        .agg(max("trade_date").alias("last_trade_date"))

    result = cust.alias("c") \
        .join(last_trade.alias("lt"), col("lt.customer_code") == col("c.customer_code"), "left") \
        .withColumn("days_since_last_trade",
                    when(col("lt.last_trade_date").isNull(), lit(999))
                    .otherwise(lit(date).cast("date").cast("long") -
                               col("lt.last_trade_date").cast("long"))) \
        .filter(col("days_since_last_trade") >= 90) \
        .select("c.customer_code", "c.customer_name", "c.customer_type",
                "lt.last_trade_date", "days_since_last_trade",
                lit(date).alias("as_of_date"), lit(date).alias("_load_date"))
    return result


# ====== Report 8: Position Concentration Risk ======
def compute_rpt_position_concentration_risk(spark: SparkSession, date: str):
    pos = spark.read.table("gold.gold.fact_position_daily").filter(col("position_date") == date)
    sec = spark.read.table("gold.gold.dim_security")
    account = spark.read.table("gold.gold.dim_account")

    # Portfolio value per account
    acct_portfolio = pos.groupBy("account_id", "product_type") \
        .agg(sum("market_value").alias("portfolio_value"))

    result = pos.alias("p") \
        .join(acct_portfolio.alias("ap"),
              (col("ap.account_id") == col("p.account_id")) &
              (col("ap.product_type") == col("p.product_type"))) \
        .join(sec.alias("s"), col("s.security_id") == col("p.instrument_id"), "left") \
        .join(account.alias("a"),
              (col("a.account_id") == col("p.account_id")) &
              (col("a.product_type") == col("p.product_type"))) \
        .select(
            col("p.product_type"), col("p.account_id"), col("a.customer_code"),
            col("p.instrument_id"), col("s.symbol"), col("s.sector"),
            col("p.market_value"), col("ap.portfolio_value"),
            (col("p.market_value") / col("ap.portfolio_value")).alias("concentration_pct"),
            when(col("p.market_value") / col("ap.portfolio_value") > 0.3, lit("HIGH"))
            .otherwise(lit("NORMAL")).alias("risk_level"),
            lit(date).alias("position_date"), lit(date).alias("_load_date"))
    return result


# ====== Report 9: Margin Call Alert ======
def compute_rpt_margin_call_alert(spark: SparkSession, date: str):
    margin = spark.read.table("gold.gold.fact_margin_loan_daily").filter(col("loan_date") == date)
    account = spark.read.table("gold.gold.dim_account")
    broker = spark.read.table("gold.gold.dim_broker")
    cust = spark.read.table("gold.gold.dim_customer")

    result = margin.alias("m") \
        .join(account.alias("a"),
              (col("a.product_type") == col("m.product_type")) &
              (col("a.account_id") == col("m.account_id"))) \
        .join(cust.alias("c"), col("c.customer_code") == col("a.customer_code")) \
        .join(broker.alias("b"), col("b.broker_code") == col("a.broker_code")) \
        .filter(col("m.call_margin_flag") == True) \
        .select(
            col("m.product_type"), col("m.account_id"), col("a.account_no"),
            col("a.customer_code"), col("c.customer_name"),
            col("a.broker_code"), col("b.broker_name"),
            col("m.margin_ratio"), col("m.maintenance_margin_ratio"),
            col("m.margin_loan_balance"),
            lit(date).alias("alert_date"), lit(date).alias("_load_date"))
    return result


# ====== Report 10: OEF Fund Flow ======
def compute_rpt_oef_fund_flow(spark: SparkSession, date: str):
    trades = spark.read.table("gold.gold.fact_oef_trade").filter(col("trade_date") == date)
    fund = spark.read.table("gold.gold.dim_fund")
    nav = spark.read.table("gold.gold.dim_fund_nav_history").filter(col("nav_date") == date)

    result = trades.alias("t") \
        .join(fund.alias("f"), col("f.fund_id") == col("t.fund_id")) \
        .join(nav.alias("nav"), (col("nav.fund_id") == col("t.fund_id")) &
                                 (col("nav.nav_date") == col("t.trade_date")), "left") \
        .groupBy("t.trade_date", "t.fund_id", "f.fund_code", "f.fund_name", "nav.nav_price") \
        .agg(
            sum(when(col("t.transaction_type") == "SUBSCRIBE", col("t.amount")).otherwise(0))
                .alias("subscribe_amount"),
            sum(when(col("t.transaction_type") == "REDEEM", col("t.amount")).otherwise(0))
                .alias("redeem_amount"),
            countDistinct("t.customer_code").alias("trading_customer_count")
        ) \
        .withColumn("net_flow_amount", col("subscribe_amount") - col("redeem_amount")) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 11: Customer Investment Performance ======
def compute_rpt_customer_investment_performance(spark: SparkSession, date: str):
    balance = spark.read.table("gold.gold.fact_account_balance_daily")
    account = spark.read.table("gold.gold.dim_account")
    index_price = spark.read.table("gold.gold.dim_market_index_price")

    current_month = date[:7]  # YYYY-MM

    # Monthly customer values
    cmv = balance.alias("f") \
        .join(account.alias("a"),
              (col("a.product_type") == col("f.product_type")) &
              (col("a.account_id") == col("f.account_id"))) \
        .groupBy("a.customer_code",
                 year("f.balance_date").alias("value_year"),
                 month("f.balance_date").alias("value_month")) \
        .agg(
            min_by("f.total_asset_value", "f.balance_date").alias("start_value"),
            max_by("f.total_asset_value", "f.balance_date").alias("end_value"))

    # VN-Index monthly values
    vnindex = index_price.filter(col("index_code") == "VNINDEX") \
        .groupBy(year("price_date").alias("value_year"),
                 month("price_date").alias("value_month")) \
        .agg(
            min_by("close_value", "price_date").alias("start_index"),
            max_by("close_value", "price_date").alias("end_index"))

    result = cmv.alias("cmv") \
        .join(vnindex.alias("vi"),
              (col("vi.value_year") == col("cmv.value_year")) &
              (col("vi.value_month") == col("cmv.value_month"))) \
        .select(
            col("cmv.customer_code"), col("cmv.value_year"), col("cmv.value_month"),
            col("cmv.start_value"), col("cmv.end_value"),
            ((col("cmv.end_value") - col("cmv.start_value")) / col("cmv.start_value"))
                .alias("customer_return_pct"),
            ((col("vi.end_index") - col("vi.start_index")) / col("vi.start_index"))
                .alias("vnindex_return_pct")) \
        .withColumn("_load_date", lit(date))
    return result


# ====== Report 12: Customer Cross-Sell ======
def compute_rpt_customer_cross_sell(spark: SparkSession, date: str):
    equity = spark.read.table("gold.gold.fact_equity_trade").filter(col("trade_date") == date)
    deriv = spark.read.table("gold.gold.fact_derivative_trade").filter(col("trade_date") == date)
    oef = spark.read.table("gold.gold.fact_oef_trade").filter(col("trade_date") == date)
    cust = spark.read.table("gold.gold.dim_customer")

    eq_custs = equity.select("customer_code").distinct().withColumn("has_equity", lit(True))
    de_custs = deriv.select("customer_code").distinct().withColumn("has_derivatives", lit(True))
    oef_custs = oef.select("customer_code").distinct().withColumn("has_oef", lit(True))

    result = cust.alias("c") \
        .join(eq_custs.alias("eq"), col("eq.customer_code") == col("c.customer_code"), "left") \
        .join(de_custs.alias("de"), col("de.customer_code") == col("c.customer_code"), "left") \
        .join(oef_custs.alias("oef"), col("oef.customer_code") == col("c.customer_code"), "left") \
        .fillna(False) \
        .select(
            col("c.customer_code"), col("c.customer_name"),
            col("has_equity"), col("has_derivatives"), col("has_oef"),
            (when(col("has_equity"), 1).otherwise(0) +
             when(col("has_derivatives"), 1).otherwise(0) +
             when(col("has_oef"), 1).otherwise(0)).alias("product_count"),
            lit(date).alias("_load_date"))
    return result


# ====== Report 13: Management Override Commission ======
def compute_rpt_management_override_commission(spark: SparkSession, date: str):
    # Uses broker_kpi from business layer, management commission schedule
    broker_kpi = spark.read.table("business.business.broker_kpi").filter(col("_load_date") == date)
    mgmt_sched = spark.read.table("gold.gold.dim_management_commission_schedule") \
        .filter(col("is_current") == True)

    result = broker_kpi.alias("k") \
        .crossJoin(mgmt_sched.alias("ms")) \
        .select(
            col("k.broker_code"), col("k.broker_name"),
            col("k.total_commission"), col("k.rank"),
            col("ms.management_level"),
            col("ms.commission_rate"),
            (col("k.total_commission") * col("ms.commission_rate"))
                .alias("management_commission_amount"),
            lit(date).alias("_load_date"))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Processing date (YYYY-MM-DD)")
    args = parser.parse_args()

    spark = create_spark_session()
    date = args.date

    # Dictionary of all report functions
    reports = {
        "rpt_broker_commission_revenue": compute_rpt_broker_commission_revenue,
        "rpt_department_branch_ranking": compute_rpt_department_branch_ranking,
        "rpt_broker_performance": compute_rpt_broker_performance,
        "rpt_trading_activity_summary": compute_rpt_trading_activity_summary,
        "rpt_aum_summary": compute_rpt_aum_summary,
        "rpt_customer_acquisition_funnel": compute_rpt_customer_acquisition_funnel,
        "rpt_customer_dormant": compute_rpt_customer_dormant,
        "rpt_position_concentration_risk": compute_rpt_position_concentration_risk,
        "rpt_margin_call_alert": compute_rpt_margin_call_alert,
        "rpt_oef_fund_flow": compute_rpt_oef_fund_flow,
        "rpt_customer_investment_performance": compute_rpt_customer_investment_performance,
        "rpt_customer_cross_sell": compute_rpt_customer_cross_sell,
        "rpt_management_override_commission": compute_rpt_management_override_commission,
    }

    for name, func in reports.items():
        print(f"\n[STEP] Computing {name} for {date}")
        try:
            df = func(spark, date)
            write_report(df, name, date)
        except Exception as e:
            print(f"[ERROR] {name}: {e}")

    # Also compute broker_kpi and customer_kpi (business layer)
    print(f"\n[STEP] Computing broker_kpi for {date}")
    try:
        from business_processing import compute_broker_kpi
        compute_broker_kpi(spark, date)
    except Exception as e:
        print(f"[WARN] broker_kpi not computed: {e}")

    spark.stop()
    print(f"\n[DONE] Commission Engine for {date}")


if __name__ == "__main__":
    main()