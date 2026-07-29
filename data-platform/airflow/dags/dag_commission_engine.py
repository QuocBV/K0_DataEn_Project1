"""
DAG: Commission Engine
Runs Spark Commission Engine: reads Gold dim/fact, computes 13 reports + KPI,
writes to reporting.* Iceberg tables on s3://company-report/reporting/.
"""
from datetime import datetime
from airflow import DAG, Dataset
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from _common import DEFAULT_ARGS

SPARK_JOBS_DIR = "/opt/airflow/data-platform/spark/jobs"
DS_COMMISSION_COMPLETE = Dataset("s3://company-report/_SUCCESS")

with DAG(
    dag_id="commission_engine",
    default_args=DEFAULT_ARGS,
    description="Spark: compute 13 reports from Gold → reporting.* Iceberg",
    schedule=None,
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["spark", "commission", "reporting"],
) as dag:

    commission_run = SparkSubmitOperator(
        task_id="commission_engine_run",
        application=f"{SPARK_JOBS_DIR}/commission_engine.py",
        name="CommissionEngine",
        conn_id="spark_default",
        application_args=["--date", "{{ ds }}"],
        packages="org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3",
        executor_memory="8g",
        driver_memory="4g",
        num_executors=4,
        outlets=[DS_COMMISSION_COMPLETE],
    )

    commission_run