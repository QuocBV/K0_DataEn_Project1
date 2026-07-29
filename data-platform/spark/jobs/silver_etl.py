"""
Silver ETL: Reads Bronze Iceberg tables, performs cleaning, deduplication,
standardization, joins for enrichment, applies basic business rules,
writes Silver Iceberg tables.

Usage (spark-submit):
  spark-submit --packages org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3 \
    silver_etl.py --date 2027-06-01
"""
import argparse
import os
import sys
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, row_number, coalesce, when, trim, upper, lit
from pyspark.sql.window import Window

BRONZE_BUCKET = "s3a://ssi-bronze"
SILVER_BUCKET = "s3a://ssi-silver"
DATABASE = "silver"


def create_spark_session():
    """Create Spark session with Iceberg and S3 config."""
    return SparkSession.builder \
        .appName("SilverETL") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.bronze", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.bronze.type", "hadoop") \
        .config("spark.sql.catalog.bronze.warehouse", BRONZE_BUCKET) \
        .config("spark.sql.catalog.silver", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.silver.type", "hadoop") \
        .config("spark.sql.catalog.silver.warehouse", SILVER_BUCKET) \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", "")) \
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", "")) \
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("AWS_S3_ENDPOINT", "s3.amazonaws.com")) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .getOrCreate()


def deduplicate(df: DataFrame, partition_cols: list, order_col: str = "_loaded_at") -> DataFrame:
    """Remove duplicates keeping the latest record based on order_col."""
    window_spec = Window.partitionBy(*partition_cols).orderBy(col(order_col).desc())
    return df.withColumn("_rn", row_number().over(window_spec)) \
             .filter(col("_rn") == 1) \
             .drop("_rn")


def clean_broker(df: DataFrame) -> DataFrame:
    """Standardize broker codes, trim whitespace."""
    return df.withColumn("broker_code", trim(upper(col("broker_code")))) \
             .withColumn("broker_name", trim(col("broker_name"))) \
             .withColumn("broker_type", upper(trim(col("broker_type")))) \
             .withColumn("broker_subtype", upper(trim(col("broker_subtype"))))


def clean_customer(df: DataFrame) -> DataFrame:
    """Standardize customer codes, drop PII (id_number)."""
    # Drop PII: id_number should NOT be carried to analytics layer
    cols_to_drop = [c for c in df.columns if c.lower() == "id_number"]
    df = df.drop(*cols_to_drop)
    return df.withColumn("customer_code", trim(upper(col("customer_code")))) \
             .withColumn("customer_type", upper(trim(col("customer_type")))) \
             .withColumn("residency", upper(trim(col("residency"))))


def clean_trade(df: DataFrame) -> DataFrame:
    """Standardize trade records."""
    return df.withColumn("customer_code", trim(upper(col("customer_code")))) \
             .withColumn("broker_code", trim(upper(col("broker_code")))) \
             .withColumn("side", upper(trim(col("side")))) \
             .withColumn("source_system", upper(trim(col("source_system"))))


def process_silver_table(spark: SparkSession, table: str, date: str):
    """Read Bronze Iceberg table, clean, dedup, write to Silver."""
    bronze_table = f"bronze.{DATABASE}.{table}"
    silver_table = f"silver.{DATABASE}.{table}"

    df = spark.read.table(bronze_table) \
              .filter(col("_load_date") == date)

    if df.rdd.isEmpty():
        print(f"[SKIP] No Bronze data for {table} on {date}")
        return

    print(f"[INFO] Read {df.count()} rows from {bronze_table} for {date}")

    # Apply cleaning based on table type
    if table == "broker":
        df = clean_broker(df)
    elif table == "customer":
        df = clean_customer(df)
    elif table in ("equity_trade", "derivative_trade", "oef_trade"):
        df = clean_trade(df)

    # Deduplicate by natural key (customize per table as needed)
    if table in ("branch", "department"):
        df = deduplicate(df, ["branch_id" if table == "branch" else "department_id"])
    elif table == "broker":
        df = deduplicate(df, ["broker_code"])
    elif table == "customer":
        df = deduplicate(df, ["customer_code"])
    elif table == "security":
        df = deduplicate(df, ["security_id"])
    elif table in ("equity_trade", "derivative_trade", "oef_trade"):
        df = deduplicate(df, ["source_system", "source_trade_id", "trade_date"])
    elif table in ("account_balance_daily", "position_daily", "margin_loan_daily"):
        # Composite key varies; use _loaded_at dedup on all cols minus metadata
        metadata_cols = ["_loaded_at", "_source_file", "_source_db", "_source_table", "_load_date", "_rn"]
        natural_cols = [c for c in df.columns if c not in metadata_cols]
        df = deduplicate(df, natural_cols)
    else:
        pass  # Keep as-is

    # Write to Silver
    df.write \
      .mode("overwrite") \
      .format("iceberg") \
      .option("replace-where", f"_load_date = '{date}'") \
      .partitionBy("_load_date") \
      .saveAsTable(silver_table)

    print(f"[INFO] Wrote to {silver_table}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Load date (YYYY-MM-DD)")
    args = parser.parse_args()

    spark = create_spark_session()
    date = args.date

    # All tables across all sources
    all_tables = [
        "branch", "department", "broker", "customer", "customer_broker_history",
        "customer_risk_profile", "customer_segment_history", "customer_acquisition",
        "fee_schedule", "management_commission_schedule", "market_index_price",
        "trading_alert", "customer_complaint",
        "security", "daily_price", "account",
        "equity_trade", "account_balance_daily", "position_daily", "margin_loan_daily",
        "derivative_contract", "daily_settlement_price", "derivative_trade",
        "fund", "fund_nav_history", "oef_trade",
        "employees"
    ]

    for table in all_tables:
        try:
            process_silver_table(spark, table, date)
        except Exception as e:
            print(f"[ERROR] Failed processing {table}: {e}")

    spark.stop()
    print(f"[DONE] Silver ETL for {date}")


if __name__ == "__main__":
    main()