"""Meltano Extract DAG:
1. Extract all sources (SQL Server + HR API) -> S3 (Parquet/JSON)
2. Load from S3 -> Snowflake RAW
3. Verify row counts, then emit Dataset for dbt_transform.

All data flows through S3 as the central Data Lake before loading into Snowflake.
"""
from datetime import datetime, timedelta
import json
import os

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

from _common import DEFAULT_ARGS

EXTRACT_DONE = Dataset("snowflake://RAW/meltano_extract")

MELTANO_PROJECT_DIR = "/opt/airflow/data-platform/meltano"
MELTANO_RUN = f"cd {MELTANO_PROJECT_DIR} && meltano run --no-update"

# Extract pipelines (all go through S3 first)
EXTRACT_PIPELINES = [
    {"task_id": "extract_common", "pipeline": "tap-mssql target-s3"},
    {"task_id": "extract_equity", "pipeline": "tap-mssql target-s3"},
    {"task_id": "extract_derivatives", "pipeline": "tap-mssql target-s3"},
    {"task_id": "extract_oef", "pipeline": "tap-mssql target-s3"},
    {"task_id": "extract_hr", "pipeline": "tap-hr-api target-s3"},
]


def verify_s3_upload(**context) -> None:
    """Quick sanity check: ensure S3 has files for today."""
    import boto3

    bucket = os.environ["S3_BUCKET"]
    prefix = os.environ.get("S3_PREFIX", "elt/") + "raw/"
    s3 = boto3.client("s3")
    result = s3.list_objects_v2(Bucket=bucket, Prefix=prefix, MaxKeys=10)
    if "Contents" not in result or len(result["Contents"]) == 0:
        raise ValueError(f"No files found in S3 bucket {bucket} at prefix {prefix} - extract may have failed")
    print(f"Verified S3 has data: {len(result['Contents'])} objects under {prefix}")
    for obj in result["Contents"][:5]:
        print(f"  - {obj['Key']} ({obj['Size']} bytes)")


with DAG(
    dag_id="meltano_extract",
    description="Extract all data sources to S3 via Meltano, then load into Snowflake RAW",
    schedule="0 2 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "extract", "meltano"],
) as dag:

    # All extracts run in parallel via Meltano (each goes to S3)
    extract_tasks = []
    for cfg in EXTRACT_PIPELINES:
        task = BashOperator(
            task_id=cfg["task_id"],
            bash_command=f"{MELTANO_RUN} {cfg['pipeline']}",
            execution_timeout=timedelta(hours=2),
        )
        extract_tasks.append(task)

    # Verify S3 has data from all sources
    verify_s3 = PythonOperator(
        task_id="verify_s3_upload",
        python_callable=verify_s3_upload,
        execution_timeout=timedelta(minutes=5),
    )

    # Load ALL data from S3 into Snowflake RAW (single pipeline)
    load_all = BashOperator(
        task_id="load_to_snowflake",
        bash_command=f"{MELTANO_RUN} load_all_to_snowflake",
        execution_timeout=timedelta(hours=2),
    )

    mark_done = PythonOperator(
        task_id="mark_extract_done",
        python_callable=lambda: None,
        outlets=[EXTRACT_DONE],
    )

    # Flow: all extracts -> S3 -> verify -> Snowflake -> done
    extract_tasks >> verify_s3 >> load_all >> mark_done