"""
Generate synthetic trades for a given date, using real customer/broker/security data
from Silver Iceberg tables. Writes directly to Silver so the pipeline can process them.

Usage:
  spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3 \
    generate_trades.py --date 2027-06-15 --num_equity 10000 --num_derivatives 500 --num_oef 200
"""
import argparse
import os
import random
from datetime import datetime, timedelta
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, lit, rand, when, expr, row_number, monotonically_increasing_id
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, LongType,
    DecimalType, TimestampType, DateType, BooleanType
)

SILVER_BUCKET = "s3a://ssi-silver"
random.seed(42)


def create_spark_session():
    """Create Spark session with Iceberg and S3 config."""
    return SparkSession.builder \
        .appName("GenerateTrades") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.silver", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.silver.type", "hadoop") \
        .config("spark.sql.catalog.silver.warehouse", SILVER_BUCKET) \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", "")) \
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", "")) \
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("AWS_S3_ENDPOINT", "s3.amazonaws.com")) \
        .getOrCreate()


def load_dimensions(spark: SparkSession) -> dict:
    """Load dimension tables from Silver layer and return as dict of lists."""
    dims = {}

    # Customers
    df = spark.read.table("silver.silver.customer")
    rows = df.select("customer_code", "customer_type", "residency").collect()
    dims["customers"] = [(r.customer_code, r.customer_type, r.residency) for r in rows]

    # Brokers
    df = spark.read.table("silver.silver.broker")
    rows = df.select("broker_code", "broker_type").collect()
    dims["brokers"] = [(r.broker_code, r.broker_type) for r in rows]

    # Securities (Equity)
    df = spark.read.table("silver.silver.security")
    rows = df.select("security_id", "symbol", "exchange", "sector").collect()
    dims["securities"] = [(r.security_id, r.symbol, r.exchange, r.sector) for r in rows]

    # Derivative contracts
    try:
        df = spark.read.table("silver.silver.derivative_contract")
        rows = df.select("contract_id", "contract_code", "maturity_date", "multiplier").collect()
        dims["contracts"] = [(r.contract_id, r.contract_code, r.maturity_date, r.multiplier) for r in rows]
    except Exception:
        print("[WARN] No derivative_contract table found, using empty list")
        dims["contracts"] = []

    # Funds (OEF)
    try:
        df = spark.read.table("silver.silver.fund")
        rows = df.select("fund_id", "fund_code", "fund_type").collect()
        dims["funds"] = [(r.fund_id, r.fund_code, r.fund_type) for r in rows]
    except Exception:
        print("[WARN] No fund table found, using empty list")
        dims["funds"] = []

    # Accounts (Equity)
    df = spark.read.table("silver.silver.account")
    rows = df.select("account_id", "account_no", "customer_code").collect()
    dims["accounts"] = [(r.account_id, r.account_no, r.customer_code) for r in rows]

    # Customer-Broker assignments
    df = spark.read.table("silver.silver.customer_broker_history")
    rows = df.filter(col("is_current") == True) \
             .select("customer_code", "broker_code").collect()
    dims["customer_broker"] = {r.customer_code: r.broker_code for r in rows}

    print(f"[INFO] Loaded: {len(dims['customers'])} customers, {len(dims['brokers'])} brokers, "
          f"{len(dims['securities'])} securities, {len(dims['contracts'])} contracts, "
          f"{len(dims['funds'])} funds, {len(dims['accounts'])} accounts")
    return dims


def generate_prices():
    """Return random price within reasonable ranges per exchange."""
    return {
        "HOSE": round(random.uniform(10.0, 150.0), 2),
        "HNX": round(random.uniform(5.0, 80.0), 2),
        "UPCOM": round(random.uniform(3.0, 50.0), 2),
    }


def generate_equity_trades(spark: SparkSession, dims: dict, trade_date: str, num_trades: int):
    """Generate equity trades with valid references."""
    if not dims["customers"] or not dims["brokers"] or not dims["securities"]:
        print("[ERROR] Missing required dimensions for equity trades")
        return None

    rows = []
    for i in range(num_trades):
        customer_code, cust_type, residency = random.choice(dims["customers"])
        broker_code = dims["customer_broker"].get(customer_code, random.choice(dims["brokers"])[0])
        sec_id, symbol, exchange, sector = random.choice(dims["securities"])
        # Find account for this customer
        customer_accounts = [a for a in dims["accounts"] if a[2] == customer_code]
        account_no = customer_accounts[0][1] if customer_accounts else f"EQ{random.randint(10000, 99999)}"

        side = random.choice(["BUY", "SELL"])
        quantity = random.choice([100, 200, 300, 500, 1000, 2000, 5000])
        price = generate_prices()[exchange]
        amount = round(quantity * price, 2)
        fee_rate = 0.0025 if side == "BUY" else 0.0025
        fee_amount = round(amount * fee_rate, 2)
        tax_amount = round(amount * 0.001, 2)  # 0.1% sell tax

        hour = random.randint(9, 14)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        trade_datetime = f"{trade_date} {hour:02d}:{minute:02d}:{second:02d}"

        rows.append((
            i + 1, trade_date, trade_datetime, f"SRC_EQ_{trade_date}_{i+1}",
            account_no, customer_code, broker_code,
            sec_id, symbol, exchange, sector,
            side, quantity, price, amount, fee_amount, tax_amount,
            "FILLED", trade_date
        ))

    schema = StructType([
        StructField("trade_id", LongType(), False),
        StructField("trade_date", DateType(), False),
        StructField("trade_datetime", StringType(), True),
        StructField("source_trade_id", StringType(), True),
        StructField("account_no", StringType(), True),
        StructField("customer_code", StringType(), True),
        StructField("broker_code", StringType(), True),
        StructField("security_id", IntegerType(), True),
        StructField("symbol", StringType(), True),
        StructField("market", StringType(), True),
        StructField("sector", StringType(), True),
        StructField("side", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("price", DecimalType(18, 2), True),
        StructField("amount", DecimalType(18, 2), True),
        StructField("fee_amount", DecimalType(18, 2), True),
        StructField("tax_amount", DecimalType(18, 2), True),
        StructField("status", StringType(), True),
        StructField("_load_date", StringType(), True),
    ])

    df = spark.createDataFrame(rows, schema)
    return df


def generate_derivative_trades(spark: SparkSession, dims: dict, trade_date: str, num_trades: int):
    """Generate derivative trades with valid references."""
    if not dims["contracts"]:
        print("[WARN] No derivative contracts, skipping")
        return None

    rows = []
    for i in range(num_trades):
        customer_code, _, _ = random.choice(dims["customers"])
        broker_code = dims["customer_broker"].get(customer_code, random.choice(dims["brokers"])[0])
        customer_accounts = [a for a in dims["accounts"] if a[2] == customer_code]
        account_no = customer_accounts[0][1] if customer_accounts else f"DE{random.randint(10000, 99999)}"

        contract_id, contract_code, maturity_date, multiplier = random.choice(dims["contracts"])
        position_side = random.choice(["LONG", "SHORT"])
        order_action = random.choice(["OPEN", "CLOSE"])
        quantity = random.choice([1, 2, 5, 10, 20])
        price = round(random.uniform(800, 1500), 2)
        amount = round(quantity * price * (multiplier or 100000), 2)
        margin_amount = round(amount * 0.15, 2)  # ~15% margin
        fee_amount = round(amount * 0.0005, 2)

        hour = random.randint(9, 14)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        trade_datetime = f"{trade_date} {hour:02d}:{minute:02d}:{second:02d}"

        rows.append((
            i + 1, trade_date, trade_datetime, f"SRC_DE_{trade_date}_{i+1}",
            account_no, customer_code, broker_code,
            contract_id, contract_code, position_side, order_action,
            quantity, price, amount, margin_amount, fee_amount,
            "FILLED", trade_date
        ))

    schema = StructType([
        StructField("trade_id", LongType(), False),
        StructField("trade_date", DateType(), False),
        StructField("trade_datetime", StringType(), True),
        StructField("source_trade_id", StringType(), True),
        StructField("account_no", StringType(), True),
        StructField("customer_code", StringType(), True),
        StructField("broker_code", StringType(), True),
        StructField("contract_id", IntegerType(), True),
        StructField("contract_code", StringType(), True),
        StructField("position_side", StringType(), True),
        StructField("order_action", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("price", DecimalType(18, 2), True),
        StructField("amount", DecimalType(18, 2), True),
        StructField("margin_amount", DecimalType(18, 2), True),
        StructField("fee_amount", DecimalType(18, 2), True),
        StructField("status", StringType(), True),
        StructField("_load_date", StringType(), True),
    ])

    df = spark.createDataFrame(rows, schema)
    return df


def generate_oef_trades(spark: SparkSession, dims: dict, trade_date: str, num_trades: int):
    """Generate OEF fund trades (subscribe/redeem/switch) with valid references."""
    if not dims["funds"]:
        print("[WARN] No funds, skipping OEF trades")
        return None

    rows = []
    for i in range(num_trades):
        customer_code, _, _ = random.choice(dims["customers"])
        broker_code = dims["customer_broker"].get(customer_code, random.choice(dims["brokers"])[0])
        customer_accounts = [a for a in dims["accounts"] if a[2] == customer_code]
        account_no = customer_accounts[0][1] if customer_accounts else f"OE{random.randint(10000, 99999)}"

        fund_id, fund_code, fund_type = random.choice(dims["funds"])
        transaction_type = random.choices(
            ["SUBSCRIBE", "REDEEM", "SWITCH"],
            weights=[0.6, 0.3, 0.1]
        )[0]
        nav_price = round(random.uniform(8000, 25000), 2)  # VND/unit
        quantity_unit = random.choice([100, 200, 500, 1000, 2000])
        amount = round(quantity_unit * nav_price, 2)
        fee_amount = round(amount * 0.01, 2)  # ~1% subscription fee

        hour = random.randint(9, 14)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        trade_datetime = f"{trade_date} {hour:02d}:{minute:02d}:{second:02d}"

        rows.append((
            i + 1, trade_date, trade_datetime, f"SRC_OEF_{trade_date}_{i+1}",
            account_no, customer_code, broker_code,
            fund_id, fund_code, transaction_type,
            quantity_unit, nav_price, amount, fee_amount,
            "FILLED", trade_date
        ))

    schema = StructType([
        StructField("trade_id", LongType(), False),
        StructField("trade_date", DateType(), False),
        StructField("trade_datetime", StringType(), True),
        StructField("source_trade_id", StringType(), True),
        StructField("account_no", StringType(), True),
        StructField("customer_code", StringType(), True),
        StructField("broker_code", StringType(), True),
        StructField("fund_id", IntegerType(), True),
        StructField("fund_code", StringType(), True),
        StructField("transaction_type", StringType(), True),
        StructField("quantity_unit", IntegerType(), True),
        StructField("nav_price", DecimalType(18, 2), True),
        StructField("amount", DecimalType(18, 2), True),
        StructField("fee_amount", DecimalType(18, 2), True),
        StructField("status", StringType(), True),
        StructField("_load_date", StringType(), True),
    ])

    df = spark.createDataFrame(rows, schema)
    return df


def write_trades(df: DataFrame, table_name: str, trade_date: str):
    """Write trades to Silver Iceberg table."""
    if df is None or df.rdd.isEmpty():
        print(f"[SKIP] No data for {table_name}")
        return

    target = f"silver.silver.{table_name}"
    print(f"[INFO] Writing {df.count()} rows to {target}")

    df.write \
      .mode("overwrite") \
      .format("iceberg") \
      .option("replace-where", f"_load_date = '{trade_date}'") \
      .partitionBy("_load_date") \
      .saveAsTable(target)

    print(f"[DONE] Wrote {table_name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Trade date (YYYY-MM-DD)")
    parser.add_argument("--num_equity", type=int, default=10000, help="Number of equity trades")
    parser.add_argument("--num_derivatives", type=int, default=500, help="Number of derivative trades")
    parser.add_argument("--num_oef", type=int, default=200, help="Number of OEF trades")
    args = parser.parse_args()

    spark = create_spark_session()
    dims = load_dimensions(spark)

    if not dims["customers"]:
        print("[ERROR] No customers found in Silver layer. Run Silver ETL first.")
        spark.stop()
        return

    # Generate and write equity trades
    print(f"\n[STEP] Generating {args.num_equity} equity trades for {args.date}")
    eq_df = generate_equity_trades(spark, dims, args.date, args.num_equity)
    write_trades(eq_df, "equity_trade", args.date)

    # Generate and write derivative trades
    print(f"\n[STEP] Generating {args.num_derivatives} derivative trades for {args.date}")
    de_df = generate_derivative_trades(spark, dims, args.date, args.num_derivatives)
    write_trades(de_df, "derivative_trade", args.date)

    # Generate and write OEF trades
    print(f"\n[STEP] Generating {args.num_oef} OEF trades for {args.date}")
    oef_df = generate_oef_trades(spark, dims, args.date, args.num_oef)
    write_trades(oef_df, "oef_trade", args.date)

    spark.stop()
    print(f"\n[DONE] Generated trades for {args.date}")


if __name__ == "__main__":
    main()