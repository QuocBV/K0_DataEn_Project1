"""
DAG 7: Gold Quality
Runs dbt test and Soda quality checks on Gold Iceberg tables.
"""
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.models.baseoperator import chain
from _common import DEFAULT_ARGS

DBT_DIR = "/opt/airflow/data-platform/dbt"

with DAG(
    dag_id="gold_quality",
    default_args=DEFAULT_ARGS,
    description="dbt test + Soda quality checks on Gold layer",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["dbt", "soda", "gold", "quality"],
) as dag:

    dbt_test = BashOperator(
        task_id="dbt_test_gold",
        bash_command=f"cd {DBT_DIR} && dbt test --select path:models/marts path:snapshots",
    )

    soda_scan = BashOperator(
        task_id="soda_scan_gold",
        bash_command=(
            "soda scan "
            "-d ssi_trino "
            "-c /opt/airflow/data-platform/soda/configuration.yml "
            "/opt/airflow/data-platform/soda/checks/gold/gold_quality.yml "
        ),
    )

    dbt_test >> soda_scan