"""
DAG: Generate Trades
Sinh giao dịch giả (Equity, Derivatives, OEF) cho ngày hiện tại, dựa trên dữ liệu
khách hàng/môi giới/chứng khoán có thật từ Silver layer. Chạy trước pipeline chính
để có dữ liệu giao dịch.

Spark job generate_trades.py đọc dimension từ Silver Iceberg và sinh giao dịch
với customer_code/broker_code/security_id hợp lệ, ghi trực tiếp vào Silver.
"""
from datetime import datetime
from airflow import DAG, Dataset
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from _common import DEFAULT_ARGS

SPARK_JOBS_DIR = "/opt/airflow/data-platform/spark/jobs"

# Dataset này sẽ trigger main_pipeline sau khi trades được sinh
DS_TRADES_GENERATED = Dataset("s3://ssi-data/silver/_TRADES_GENERATED")

with DAG(
    dag_id="generate_trades",
    default_args=DEFAULT_ARGS,
    description="Generate synthetic trades using real customer/broker data from Silver layer",
    schedule="@daily",
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["data-generation", "trades"],
) as dag:

    generate_equity = SparkSubmitOperator(
        task_id="generate_equity_trades",
        application=f"{SPARK_JOBS_DIR}/generate_trades.py",
        name="GenerateEquityTrades",
        conn_id="spark_default",
        application_args=[
            "--date", "{{ ds }}",
            "--num_equity", "10000",
            "--num_derivatives", "500",
            "--num_oef", "200",
        ],
        packages="org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.4.3",
        executor_memory="8g",
        driver_memory="4g",
        num_executors=4,
        outlets=[DS_TRADES_GENERATED],
    )

    generate_equity