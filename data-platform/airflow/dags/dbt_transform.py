"""dbt Transform DAG using Cosmos (Astronomer) - orchestrates the full dbt workflow
with the required execution order: staging -> dim/fact (excl. dim_customer_history)
-> snapshot -> dim_customer_history -> reports.
"""
from datetime import datetime

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator
from cosmos import DbtTaskGroup, ProfileConfig, ProjectConfig, ExecutionConfig
from cosmos.constants import ExecutionMode
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

from _common import DEFAULT_ARGS

# Dataset dependencies (triggered after meltano_extract completes)
EXTRACT_DONE = Dataset("snowflake://RAW/meltano_extract")
TRANSFORM_DONE = Dataset("snowflake://MARTS/transform_complete")

DBT_PROJECT_PATH = "/opt/airflow/data-platform/dbt"
DBT_PROFILES_PATH = "/opt/airflow/data-platform/dbt/profiles.yml"

profile_config = ProfileConfig(
    profile_name="ssi_analytics",
    target_name="dev",
    profiles_yml_filepath=DBT_PROFILES_PATH,
)

with DAG(
    dag_id="dbt_transform",
    description="dbt Core transform using Cosmos: staging -> dim/fact -> snapshot -> history -> reports",
    schedule=[EXTRACT_DONE],  # data-aware: triggers after meltano_extract emits EXTRACT_DONE
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "transform", "dbt", "cosmos"],
) as dag:

    # Step 1: Run staging models (views + incremental heavy tables)
    run_staging = DbtTaskGroup(
        group_id="staging",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "path:models/staging",
            "full_refresh": False,
        },
        default_args={"retries": 2},
    )

    # Step 2: Run marts dim/fact (excluding dim_customer_history)
    run_marts_base = DbtTaskGroup(
        group_id="marts_base",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "path:models/marts --exclude dim_customer_history",
            "full_refresh": False,
        },
        default_args={"retries": 2},
    )

    # Step 3: dbt snapshot (captures SCD2 state of dim_customer)
    run_snapshot = DbtTaskGroup(
        group_id="snapshot",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "path:snapshots",
        },
        default_args={"retries": 2},
    )

    # Step 4: Run dim_customer_history (depends on snapshot output)
    run_history = DbtTaskGroup(
        group_id="dim_customer_history",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "dim_customer_history",
        },
        default_args={"retries": 2},
    )

    # Step 5: Run reports (views that depend on all dim/fact being ready)
    run_reports = DbtTaskGroup(
        group_id="reports",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "path:models/marts/reports",
        },
        default_args={"retries": 2},
    )

    # Step 6: dbt test on everything
    run_tests = DbtTaskGroup(
        group_id="run_tests",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            execution_mode=ExecutionMode.LOCAL,
        ),
        operator_args={
            "select": "path:models/marts path:snapshots",
        },
        default_args={"retries": 1},
    )

    all_done = PythonOperator(
        task_id="mark_transform_complete",
        python_callable=lambda: None,
        outlets=[TRANSFORM_DONE],
    )

    # Define dependencies (matching README.md section 3: required order)
    run_staging >> run_marts_base >> run_snapshot >> run_history >> run_reports >> run_tests >> all_done
