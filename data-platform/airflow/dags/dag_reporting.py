"""
DAG: Reporting
Runs dbt reporting models (thin views that SELECT * FROM reporting.* Iceberg tables).
Triggered after Commission Engine completes.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

DBT_DIR = "/opt/airflow/data-platform/dbt"

with DAG(
    dag_id="reporting",
    default_args=DEFAULT_ARGS,
    description="dbt run: thin views over reporting.* Iceberg (SELECT *)",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["dbt", "reporting"],
) as dag:

    dbt_reporting = BashOperator(
        task_id="dbt_run_reports",
        bash_command=f"cd {DBT_DIR} && dbt run --select path:models/marts/reports",
    )

    dbt_reporting
