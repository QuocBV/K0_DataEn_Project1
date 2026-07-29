"""
Business Processing: Complex business rules, KPI calculation, ranking, scoring.
Reads Gold dim/fact tables (Silver + dbt models via Trino), computes business metrics,
writes Business Fact Iceberg tables.

Usage (spark-submit):
  spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3 \
    business_processing.py --date 2027-06-01
"""
import argparse
import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum, count, when, rank, desc, lit
from pyspark.sql.window import Window

SILVER_BUCKET = "s3a://ssi-silver"
GOLD_BUCKET = "s3a://ssi-gold"
DATABASE = "gold"


def create_spark_session():
    """Create Spark session with Iceberg and S3 config."""
    return SparkSession.builder \
        .appName("BusinessProcessing") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.silver", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.silver.type", "hadoop") \
        .config("spark.sql.catalog.silver.warehouse", SILVER_BUCKET) \
        .config("spark.sql.catalog.gold", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.gold.type", "hadoop") \
        .config("spark.sql.catalog.gold.warehouse", GOLD_BUCKET) \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", "")) \
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", "")) \
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("AWS_S3_ENDPOINT", "s3.amazonaws.com")) \
        .getOrCreate()


def compute_broker_kpi(spark: SparkSession, date: str):
    """Compute broker KPIs: total commission, customers managed, rankings."""
    # Read from Silver directly for raw metrics
    trades_equity = spark.read.table("silver.silver.equity_trade") \
                         .filter(col("trade_date") == date)
    trades_deriv = spark.read.table("silver.silver.derivative_trade") \
                        .filter(col("trade_date") == date)
    trades_oef = spark.read.table("silver.silver.oef_trade") \
                      .filter(col("trade_date") == date)
    brokers = spark.read.table("silver.silver.broker")

    # Aggregate commissions by broker
    equity_comm = trades_equity.groupBy("broker_code") \
        .agg(sum("fee_amount").alias("equity_commission"))

    deriv_comm = trades_deriv.groupBy("broker_code") \
        .agg(sum("fee_amount").alias("deriv_commission"))

    oef_comm = trades_oef.groupBy("broker_code") \
        .agg(sum("fee_amount").alias("oef_commission"))

    # Join and compute total
    broker_kpi = brokers.select("broker_code", "broker_name", "department_id") \
        .join(equity_comm, on="broker_code", how="left") \
        .join(deriv_comm, on="broker_code", how="left") \
        .join(oef_comm, on="broker_code", how="left") \
        .fillna(0) \
        .withColumn("total_commission",
                    col("equity_commission") + col("deriv_commission") + col("oef_commission")) \
        .withColumn("_load_date", lit(date))

    # Rank brokers by total commission
    window_spec = Window.orderBy(desc("total_commission"))
    broker_kpi = broker_kpi.withColumn("rank", rank().over(window_spec))

    # Write to Gold business fact table
    broker_kpi.write \
        .mode("overwrite") \
        .format("iceberg") \
        .option("replace-where", f"_load_date = '{date}'") \
        .partitionBy("_load_date") \
        .saveAsTable("gold.gold.broker_kpi")

    print(f"[INFO] broker_kpi: {broker_kpi.count()} rows")


def compute_customer_kpi(spark: SparkSession, date: str):
    """Compute customer KPIs: total trading volume, AUM estimate."""
    trades_equity = spark.read.table("silver.silver.equity_trade") \
                         .filter(col("trade_date") == date)
    positions = spark.read.table("silver.silver.position_daily") \
                     .filter(col("position_date") == date)

    # Total turnover by customer
    customer_turnover = trades_equity.groupBy("customer_code") \
        .agg(sum("amount").alias("total_turnover"),
             count("trade_id").alias("trade_count"))

    customer_kpi = customer_turnover \
        .withColumn("_load_date", lit(date))

    customer_kpi.write \
        .mode("overwrite") \
        .format("iceberg") \
        .option("replace-where", f"_load_date = '{date}'") \
        .partitionBy("_load_date") \
        .saveAsTable("gold.gold.customer_kpi")

    print(f"[INFO] customer_kpi: {customer_kpi.count()} rows")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Processing date (YYYY-MM-DD)")
    args = parser.parse_args()

    spark = create_spark_session()
    date = args.date

    compute_broker_kpi(spark, date)
    compute_customer_kpi(spark, date)

    spark.stop()
    print(f"[DONE] Business Processing for {date}")


if __name__ == "__main__":
    main()