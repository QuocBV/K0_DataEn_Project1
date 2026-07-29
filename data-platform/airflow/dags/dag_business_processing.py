"""
DAG 8: Business Processing
Runs Spark Business Processing: complex KPI calculation, ranking, scoring → Business Fact Iceberg.
"""
from datetime import datetime
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from _common import DEFAULT_ARGS

SPARK_JOBS_DIR = "/opt/airflow/data-platform/spark/jobs"

with DAG(
    dag_id="business_processing",
    default_args=DEFAULT_ARGS,
    description="Spark Business Processing: KPI, ranking, scoring → Business Fact Iceberg",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["spark", "business", "kpi"],
) as dag:

    biz_run = SparkSubmitOperator(
        task_id="business_processing_run",
        application=f"{SPARK_JOBS_DIR}/business_processing.py",
        name="BusinessProcessing",
        conn_id="spark_default",
        application_args=["--date", "{{ ds }}"],
        packages="org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3",
        executor_memory="8g",
        driver_memory="4g",
        num_executors=4,
    )

    biz_run