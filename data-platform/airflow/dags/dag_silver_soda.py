"""
DAG 5: Silver Soda
Runs Soda quality checks on Silver Iceberg tables after Silver ETL.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

with DAG(
    dag_id="silver_soda",
    default_args=DEFAULT_ARGS,
    description="Soda quality checks on Silver layer",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["soda", "silver", "quality"],
) as dag:

    silver_checks = BashOperator(
        task_id="soda_scan_silver",
        bash_command=(
            "soda scan "
            "-d ssi_trino "
            "-c /opt/airflow/data-platform/soda/configuration.yml "
            "/opt/airflow/data-platform/soda/checks/silver/silver_quality.yml "
        ),
    )

    silver_checks