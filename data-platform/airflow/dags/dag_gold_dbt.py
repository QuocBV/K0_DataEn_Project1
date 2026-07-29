"""
DAG 6: Gold dbt
Runs dbt models (dim, fact, intermediate) via Trino to build Gold Iceberg tables.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from _common import DEFAULT_ARGS

DBT_DIR = "/opt/airflow/data-platform/dbt"

with DAG(
    dag_id="gold_dbt",
    default_args=DEFAULT_ARGS,
    description="dbt run: Silver → Gold dim/fact (Iceberg tables via Trino)",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["dbt", "gold", "trino"],
) as dag:

    dbt_run = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"cd {DBT_DIR} && dbt run --select path:models/marts --exclude dim_customer_history",
    )

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"cd {DBT_DIR} && dbt snapshot",
    )

    dbt_run_history = BashOperator(
        task_id="dbt_run_dim_customer_history",
        bash_command=f"cd {DBT_DIR} && dbt run --select dim_customer_history",
    )

    # Order: dim/fact → snapshot → history (same logic as original)
    dbt_run >> dbt_snapshot >> dbt_run_history