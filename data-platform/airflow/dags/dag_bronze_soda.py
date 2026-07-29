"""
DAG 3: Bronze Soda
Runs Soda quality checks on Bronze Iceberg tables.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

with DAG(
    dag_id="bronze_soda",
    default_args=DEFAULT_ARGS,
    description="Soda quality checks on Bronze layer",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["soda", "bronze", "quality"],
) as dag:

    bronze_checks = BashOperator(
        task_id="soda_scan_bronze",
        bash_command=(
            "soda scan "
            "-d ssi_trino "
            "-c /opt/airflow/data-platform/soda/configuration.yml "
            "/opt/airflow/data-platform/soda/checks/bronze/bronze_quality.yml "
        ),
    )

    bronze_checks