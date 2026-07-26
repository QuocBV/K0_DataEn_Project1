"""E+L step 1/2: sync all small dimension/reference tables from the 4 SQL Server DBs + the HR API
into Snowflake RAW via Airbyte. Heavy trade/position/balance tables are handled separately by
dag_bulk_load_heavy_tables.py (see that file and snowflake/02_bulk_load_equity.sql for why).

Scheduled after the SQL Server nightly batch/EOD jobs are known to have finished (02:00 ICT).
Emits a Dataset on success so dag_dbt_transform.py can trigger automatically once both this DAG
and dag_bulk_load_heavy_tables.py have produced fresh data for the day (data-aware scheduling,
not a guessed cron offset).
"""
from datetime import datetime

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator

from _common import DEFAULT_ARGS

DIMENSIONS_LOADED = Dataset("snowflake://RAW/dimensions")

CONNECTIONS = {
    "sync_common": "mssql_common_to_snowflake",
    "sync_equity_dims": "mssql_equity_to_snowflake",
    "sync_derivatives_dims": "mssql_derivatives_to_snowflake",
    "sync_oef_dims": "mssql_oef_to_snowflake",
    "sync_hr": "hr_api_to_snowflake",
}

with DAG(
    dag_id="ingest_dimensions",
    description="Airbyte sync of dimension/reference tables (Common + 3 product DBs + HR API) into Snowflake RAW",
    schedule="0 2 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "ingest", "airbyte"],
) as dag:
    # Airbyte connection IDs are looked up by name via an Airflow Variable ("airbyte_connection_ids",
    # a JSON dict of resource_name -> Airbyte connection UUID) since Octavia CLI manages the
    # connections themselves (see data-platform/airbyte/connections/*.yaml). var.json (not
    # var.value) is required here because the Variable holds JSON, not a plain string.
    sync_tasks = [
        AirbyteTriggerSyncOperator(
            task_id=task_id,
            airbyte_conn_id="airbyte_default",
            connection_id="{{ var.json.airbyte_connection_ids['%s'] }}" % resource_name,
            asynchronous=False,
            timeout=3600,
            wait_seconds=30,
        )
        for task_id, resource_name in CONNECTIONS.items()
    ]
    # All 5 syncs are independent of each other - run in parallel, no need to chain them.
    # The Dataset outlet sits on a downstream marker task instead of an arbitrary sync task, so it
    # only fires once every sync in this DAG run has actually succeeded.
    all_synced = PythonOperator(
        task_id="mark_dimensions_synced",
        python_callable=lambda: None,
        outlets=[DIMENSIONS_LOADED],
    )
    sync_tasks >> all_synced
