"""Run Soda quality scans against the Iceberg lakehouse using a SparkSession.

Soda's Spark datasource requires a live SparkSession rather than a host/port
(cluster connection). This script bootstraps one pointing at the
same Iceberg tables Spark ETL writes (catalogs: gold -> s3a://ssi-data/gold,
reporting -> s3a://ssi-report/reporting) and executes the requested check YAMLs.

Usage:
  python run_scan.py <path-to-checks.yml> [<more-checks.yml> ...]
"""
import os
import sys

from pyspark.sql import SparkSession
from soda.scan import Scan


def create_spark_session() -> SparkSession:
    return (
        SparkSession.builder
        .appName("SodaQualityChecks")
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.catalog.gold", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.gold.type", "hadoop")
        .config("spark.sql.catalog.gold.warehouse", "s3a://ssi-data/gold")
        .config("spark.sql.catalog.bronze", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.bronze.type", "hadoop")
        .config("spark.sql.catalog.bronze.warehouse", "s3a://ssi-data/bronze")
        .config("spark.sql.catalog.silver", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.silver.type", "hadoop")
        .config("spark.sql.catalog.silver.warehouse", "s3a://ssi-data/silver")
        .config("spark.sql.catalog.reporting", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.reporting.type", "hadoop")
        .config("spark.sql.catalog.reporting.warehouse", "s3a://ssi-report/reporting")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.hadoop.fs.s3a.access.key", os.environ.get("AWS_ACCESS_KEY_ID", ""))
        .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("AWS_SECRET_ACCESS_KEY", ""))
        .config("spark.hadoop.fs.s3a.endpoint", os.environ.get("AWS_S3_ENDPOINT", "s3.amazonaws.com"))
        .getOrCreate()
    )


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python run_scan.py <checks.yml> [<checks.yml> ...]")
        sys.exit(2)

    spark = create_spark_session()
    scan = Scan()
    scan.add_configuration_yaml_file(
        os.path.join(os.path.dirname(__file__), "configuration.yml")
    )
    for check_file in sys.argv[1:]:
        scan.add_sodacl_yaml_file(check_file)
    scan.set_scan_definition_name("lakehouse_quality")
    scan.set_data_source_name("spark_ds")

    result = scan.execute()
    print(scan.get_logs_text())
    # 0 = pass, non-zero = failed/warn
    sys.exit(0 if result == 0 else 1)


if __name__ == "__main__":
    main()