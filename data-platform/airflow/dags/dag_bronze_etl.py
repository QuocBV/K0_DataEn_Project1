"""
DAG 2: Bronze ETL
Runs Spark Bronze ETL jobs for each source after raw data is ingested.
"""
from datetime import datetime
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.models.baseoperator import chain
from _common import DEFAULT_ARGS

SPARK_JOBS_DIR = "/opt/airflow/data-platform/spark/jobs"

SOURCES = ["common", "equity", "derivatives", "oef", "hr"]

with DAG(
    dag_id="bronze_etl",
    default_args=DEFAULT_ARGS,
    description="Spark Bronze ETL: S3 Raw → Bronze Iceberg",
    schedule=None,  # Triggered by upstream DAG
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["spark", "bronze"],
) as dag:

    tasks = []
    for source in SOURCES:
        task = SparkSubmitOperator(
            task_id=f"bronze_{source}",
            application=f"{SPARK_JOBS_DIR}/bronze_etl.py",
            name=f"BronzeETL-{source}",
            conn_id="spark_default",
            application_args=["--date", "{{ ds }}", "--source", source],
            packages="org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3",
            executor_memory="4g",
            driver_memory="2g",
            num_executors=2,
        )
        tasks.append(task)

    # All sources run in parallel
    tasks