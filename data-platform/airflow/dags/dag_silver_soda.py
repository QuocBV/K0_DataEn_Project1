"""
DAG: Silver Soda
Runs Soda quality checks on Silver Iceberg tables via Trino.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

SODA_DIR = "/opt/airflow/data-platform/soda"

with DAG(
    dag_id="silver_soda",
    default_args=DEFAULT_ARGS,
    description="Soda quality checks on Silver layer (Trino)",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["soda", "silver", "quality"],
) as dag:

    silver_checks = BashOperator(
        task_id="soda_scan_silver",
        bash_command=(
            f"soda scan -d ssi_trino "
            f"-c {SODA_DIR}/configuration.yml "
            f"{SODA_DIR}/checks/silver/silver_quality.yml "
        ),
    )

    silver_checks