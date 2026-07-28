"""Soda Core Data Quality Checks DAG.

Runs after dbt_transform completes to verify data quality on Gold layer.
"""
from datetime import datetime

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator

from _common import DEFAULT_ARGS

TRANSFORM_DONE = Dataset("snowflake://MARTS/transform_complete")

SODA_CONFIG_PATH = "/opt/airflow/data-platform/soda/configuration.yml"
SODA_CHECKS_PATH = "/opt/airflow/data-platform/soda/checks/"


def run_soda_scan(scan_name: str, **context) -> None:
    """Run a Soda scan and raise on failure."""
    from soda.scan import Scan

    scan = Scan()
    scan.set_scan_definition_name(scan_name)
    scan.set_data_source_name("snowflake_ssi")
    scan.add_configuration_yaml_file(SODA_CONFIG_PATH)
    scan.add_sodacl_yaml_files(SODA_CHECKS_PATH)
    scan.execute()

    if scan.has_check_fails():
        raise ValueError(f"Soda scan '{scan_name}' FAILED. Check logs for details.")

    print(f"Soda scan '{scan_name}' passed successfully.")


with DAG(
    dag_id="soda_checks",
    description="Run Soda Core data quality checks on dbt output",
    schedule=[TRANSFORM_DONE],
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "quality", "soda"],
) as dag:

    check_gold = PythonOperator(
        task_id="check_gold_marts",
        python_callable=run_soda_scan,
        op_kwargs={"scan_name": "ssi_gold_layer_scan"},
        execution_timeout=datetime.timedelta(minutes=15),
    )

    check_gold
