"""
Main Pipeline DAG: Orchestrates the entire Lakehouse ELT pipeline.
Triggered by Dataset from generate_trades. Uses Datasets for data-aware scheduling.

Flow:
  ingest_raw → bronze_etl → bronze_soda → silver_etl → silver_soda
  → gold_dbt → gold_quality → commission_engine → reporting
"""
from datetime import datetime
from airflow import DAG, Dataset
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from _common import DEFAULT_ARGS

# Define Datasets for each stage
DS_TRADES_GENERATED = Dataset("s3://ssi-data/silver/_TRADES_GENERATED")
DS_RAW_INGESTED = Dataset("s3://ssi-data/raw/_SUCCESS")
DS_BRONZE_COMPLETE = Dataset("s3://ssi-data/bronze/_SUCCESS")
DS_BRONZE_CHECKED = Dataset("s3://ssi-data/bronze/_QUALITY_CHECKED")
DS_SILVER_COMPLETE = Dataset("s3://ssi-data/silver/_SUCCESS")
DS_SILVER_CHECKED = Dataset("s3://ssi-data/silver/_QUALITY_CHECKED")
DS_GOLD_DBT_COMPLETE = Dataset("s3://ssi-data/gold/_DBT_COMPLETE")
DS_GOLD_CHECKED = Dataset("s3://ssi-data/gold/_QUALITY_CHECKED")
DS_COMMISSION_COMPLETE = Dataset("s3://ssi-report/_SUCCESS")

with DAG(
    dag_id="main_pipeline",
    default_args=DEFAULT_ARGS,
    description="Orchestrate the full Lakehouse ELT pipeline",
    schedule=[DS_TRADES_GENERATED],
    start_date=datetime(2027, 1, 1),
    catchup=False,
    tags=["pipeline", "orchestration"],
) as dag:

    trigger_ingest = TriggerDagRunOperator(
        task_id="trigger_ingest_raw",
        trigger_dag_id="ingest_raw",
        wait_for_completion=True,
        outlets=[DS_RAW_INGESTED],
    )

    trigger_bronze = TriggerDagRunOperator(
        task_id="trigger_bronze_etl",
        trigger_dag_id="bronze_etl",
        wait_for_completion=True,
        outlets=[DS_BRONZE_COMPLETE],
    )

    trigger_bronze_soda = TriggerDagRunOperator(
        task_id="trigger_bronze_soda",
        trigger_dag_id="bronze_soda",
        wait_for_completion=True,
        outlets=[DS_BRONZE_CHECKED],
    )

    trigger_silver = TriggerDagRunOperator(
        task_id="trigger_silver_etl",
        trigger_dag_id="silver_etl",
        wait_for_completion=True,
        outlets=[DS_SILVER_COMPLETE],
    )

    trigger_silver_soda = TriggerDagRunOperator(
        task_id="trigger_silver_soda",
        trigger_dag_id="silver_soda",
        wait_for_completion=True,
        outlets=[DS_SILVER_CHECKED],
    )

    trigger_gold = TriggerDagRunOperator(
        task_id="trigger_gold_dbt",
        trigger_dag_id="gold_dbt",
        wait_for_completion=True,
        outlets=[DS_GOLD_DBT_COMPLETE],
    )

    trigger_gold_quality = TriggerDagRunOperator(
        task_id="trigger_gold_quality",
        trigger_dag_id="gold_quality",
        wait_for_completion=True,
        outlets=[DS_GOLD_CHECKED],
    )

    trigger_commission = TriggerDagRunOperator(
        task_id="trigger_commission_engine",
        trigger_dag_id="commission_engine",
        wait_for_completion=True,
        outlets=[DS_COMMISSION_COMPLETE],
    )

    trigger_reporting = TriggerDagRunOperator(
        task_id="trigger_reporting",
        trigger_dag_id="reporting",
        wait_for_completion=True,
    )

    trigger_ingest >> trigger_bronze >> trigger_bronze_soda >> trigger_silver \
        >> trigger_silver_soda >> trigger_gold >> trigger_gold_quality \
        >> trigger_commission >> trigger_reporting