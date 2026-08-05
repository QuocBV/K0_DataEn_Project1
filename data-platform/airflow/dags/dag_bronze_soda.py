"""
DAG: Bronze Soda
Runs Soda quality checks on Bronze Iceberg tables via Spark session.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

SODA_DIR = "/opt/airflow/data-platform/soda"

with DAG(
    dag_id="bronze_soda",
    default_args=DEFAULT_ARGS,
    description="Soda quality checks on Bronze layer (Spark)",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["soda", "bronze", "quality"],
) as dag:

    bronze_checks = BashOperator(
        task_id="soda_scan_bronze",
        bash_command=(
            f"cd {SODA_DIR} && "
            f"python run_scan.py {SODA_DIR}/checks/bronze/bronze_quality.yml "
        ),
    )

    bronze_checks