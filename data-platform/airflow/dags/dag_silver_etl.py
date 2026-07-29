"""
DAG 4: Silver ETL
Runs Spark Silver ETL: Bronze Iceberg → clean/dedup/enrich → Silver Iceberg.
"""
from datetime import datetime
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from _common import DEFAULT_ARGS

SPARK_JOBS_DIR = "/opt/airflow/data-platform/spark/jobs"

with DAG(
    dag_id="silver_etl",
    default_args=DEFAULT_ARGS,
    description="Spark Silver ETL: Bronze → clean/dedup → Silver Iceberg",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["spark", "silver"],
) as dag:

    silver_run = SparkSubmitOperator(
        task_id="silver_etl_run",
        application=f"{SPARK_JOBS_DIR}/silver_etl.py",
        name="SilverETL",
        conn_id="spark_default",
        application_args=["--date", "{{ ds }}"],
        packages="org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3",
        executor_memory="8g",
        driver_memory="4g",
        num_executors=4,
    )

    silver_run