"""Shared helpers for all DAGs in this project: default_args and a failure callback.

Kept in a leading-underscore module so Airflow's DAG file processor does not try to parse it
as a top-level DAG file.
"""
import os
from datetime import timedelta


def notify_failure(context) -> None:
    """Wire this to Teams/Slack via the ops webhook - never hardcode the URL, read from env/Airflow
    Variable/Connection set up by CNTT. Left as a stub print so the DAGs are runnable without it."""
    webhook_url = os.environ.get("OPS_ALERT_WEBHOOK_URL")
    ti = context["task_instance"]
    message = f"[ELT ALERT] {ti.dag_id}.{ti.task_id} failed on {context['execution_date']}"
    if webhook_url:
        import requests  # local import: only needed on the failure path

        requests.post(webhook_url, json={"text": message}, timeout=10)
    else:
        print(message)


DEFAULT_ARGS = {
    "owner": "data-engineering",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
    "on_failure_callback": notify_failure,
    "execution_timeout": timedelta(hours=2),
}

# Airbyte connection IDs - User must set these in Airflow Variables (Admin > Variables)
# Variable name: airbyte_connection_ids
# Value: JSON object mapping resource names to Airbyte connection UUIDs
# Example:
# {
#   "mssql_common_to_s3": "abc-123",
#   "mssql_equity_to_s3": "def-456",
#   "mssql_derivatives_to_s3": "ghi-789",
#   "mssql_oef_to_s3": "jkl-012",
#   "hr_api_to_s3": "mno-345"
# }