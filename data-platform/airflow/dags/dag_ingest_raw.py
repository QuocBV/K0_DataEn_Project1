"""
DAG 1: Ingest Raw
Triggers Airbyte connections to sync MSSQL and HR API data to S3 Raw zone.
User must set Airbyte connection IDs in Airflow Variables (airbyte_connection_ids).
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.models import Variable
from _common import DEFAULT_ARGS

CONNECTION_IDS = Variable.get("airbyte_connection_ids", deserialize_json=True)

with DAG(
    dag_id="ingest_raw",
    default_args=DEFAULT_ARGS,
    description="Trigger Airbyte sync: MSSQL + HR API → S3 Raw",
    schedule="@daily",
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["ingestion", "airbyte"],
) as dag:

    sync_common = AirbyteTriggerSyncOperator(
        task_id="sync_mssql_common",
        airbyte_conn_id="airbyte_default",
        connection_id=CONNECTION_IDS["mssql_common_to_s3"],
    )

    sync_equity = AirbyteTriggerSyncOperator(
        task_id="sync_mssql_equity",
        airbyte_conn_id="airbyte_default",
        connection_id=CONNECTION_IDS["mssql_equity_to_s3"],
    )

    sync_derivatives = AirbyteTriggerSyncOperator(
        task_id="sync_mssql_derivatives",
        airbyte_conn_id="airbyte_default",
        connection_id=CONNECTION_IDS["mssql_derivatives_to_s3"],
    )

    sync_oef = AirbyteTriggerSyncOperator(
        task_id="sync_mssql_oef",
        airbyte_conn_id="airbyte_default",
        connection_id=CONNECTION_IDS["mssql_oef_to_s3"],
    )

    sync_hr = AirbyteTriggerSyncOperator(
        task_id="sync_hr_api",
        airbyte_conn_id="airbyte_default",
        connection_id=CONNECTION_IDS["hr_api_to_s3"],
    )

    # All syncs run in parallel
    [sync_common, sync_equity, sync_derivatives, sync_oef, sync_hr]