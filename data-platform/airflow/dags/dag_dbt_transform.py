"""T step of ELT: run dbt (staging -> dim/fact -> report views) once both upstream loads for the
day have completed. Scheduled on the two Datasets emitted by dag_ingest_dimensions.py and
dag_bulk_load_heavy_tables.py (data-aware scheduling) instead of a guessed cron offset after them -
if either upstream DAG is late or fails and doesn't emit its Dataset, dbt simply does not run
against a half-loaded day.
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.bash import BashOperator

from _common import DEFAULT_ARGS

DIMENSIONS_LOADED = Dataset("snowflake://RAW/dimensions")
HEAVY_TABLES_LOADED = Dataset("snowflake://RAW/heavy_tables")

DBT_PROJECT_DIR = "/opt/airflow/data-platform/dbt"
DBT_PROFILES_DIR = "/opt/airflow/data-platform/dbt"

with DAG(
    dag_id="dbt_transform",
    description="dbt run + test: staging -> dim/fact -> report views, triggered once RAW is fresh for the day",
    schedule=[DIMENSIONS_LOADED, HEAVY_TABLES_LOADED],
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "transform", "dbt"],
) as dag:
    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt deps --profiles-dir {DBT_PROFILES_DIR}",
    )

    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && dbt run --profiles-dir {DBT_PROFILES_DIR} "
            f"--select path:models/staging"
        ),
        execution_timeout=timedelta(minutes=30),
    )

    dbt_test_staging = BashOperator(
        task_id="dbt_test_staging",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && dbt test --profiles-dir {DBT_PROFILES_DIR} "
            f"--select path:models/staging"
        ),
        execution_timeout=timedelta(minutes=15),
    )

    # dim_customer_history reads from the snap_customer_profile SNAPSHOT (see
    # snapshots/snap_customer_profile.sql), which only `dbt snapshot` can update - a plain `dbt run`
    # never touches snapshots. So dim_customer must be built FIRST (this run), then the snapshot
    # diffs against that fresh state, THEN dim_customer_history can be (re)built against the
    # snapshot's now-current output. Excluding it from this step avoids it reading yesterday's
    # snapshot state.
    dbt_run_marts_dims_facts = BashOperator(
        task_id="dbt_run_marts_dims_facts",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && dbt run --profiles-dir {DBT_PROFILES_DIR} "
            f"--select path:models/marts --exclude dim_customer_history"
        ),
        execution_timeout=timedelta(minutes=45),
    )

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt snapshot --profiles-dir {DBT_PROFILES_DIR}",
        execution_timeout=timedelta(minutes=10),
    )

    dbt_run_customer_history = BashOperator(
        task_id="dbt_run_customer_history",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && dbt run --profiles-dir {DBT_PROFILES_DIR} "
            f"--select dim_customer_history"
        ),
        execution_timeout=timedelta(minutes=10),
    )

    dbt_test_marts = BashOperator(
        task_id="dbt_test_marts",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && dbt test --profiles-dir {DBT_PROFILES_DIR} "
            f"--select path:models/marts path:snapshots"
        ),
        execution_timeout=timedelta(minutes=20),
    )

    # Staging is tested before marts run: a broken staging model (e.g. a source column type
    # changed upstream) should stop the pipeline before it silently propagates into dim/fact/reports.
    (
        dbt_deps
        >> dbt_run_staging
        >> dbt_test_staging
        >> dbt_run_marts_dims_facts
        >> dbt_snapshot
        >> dbt_run_customer_history
        >> dbt_test_marts
    )
