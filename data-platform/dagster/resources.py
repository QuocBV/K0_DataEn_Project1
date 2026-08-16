"""Dagster resources: Airbyte, dbt, Spark, Trino."""
import os
from dagster_airbyte import AirbyteResource
from dagster_dbt import DbtCliResource

AIRBYTE_HOST = os.getenv("AIRBYTE_HOST", "airbyte")
AIRBYTE_PORT = os.getenv("AIRBYTE_PORT", "8000")

# Airbyte connections IDs set in Airflow-style variable/secret (user creates them in UI)
AIRBYTE_CONNECTION_IDS = {
    "mssql_common_to_s3": os.getenv("CONN_MSSQL_COMMON", ""),
    "mssql_equity_to_s3": os.getenv("CONN_MSSQL_EQUITY", ""),
    "mssql_derivatives_to_s3": os.getenv("CONN_MSSQL_DERIVATIVES", ""),
    "mssql_oef_to_s3": os.getenv("CONN_MSSQL_OEF", ""),
    "hr_api_to_s3": os.getenv("CONN_HR_API", ""),
}

airbyte_resource = AirbyteResource(host=AIRBYTE_HOST, port=AIRBYTE_PORT)

dbt_resource = DbtCliResource(
    project_dir=os.getenv("DBT_PROJECT_DIR", "/opt/airflow/data-platform/dbt"),
    profiles_dir=os.getenv("DBT_PROFILES_DIR", "/root/.dbt"),
)