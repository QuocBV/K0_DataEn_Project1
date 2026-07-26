"""E+L step 2/2: export yesterday's date partition of every heavy trade/position/balance/margin
table straight to Parquet in the landing stage (bypassing Airbyte's JDBC source - see
scripts/export_partition_to_parquet.py and snowflake/03_bulk_load_equity.sql for why), then verify
Snowpipe has actually landed the row count into Snowflake's RAW.*_RAW VARIANT tables before letting
dbt run against it.

Snowpipe itself is event-driven (fires on file arrival), so this DAG's job is: (1) produce a
correctly-named, deterministic partition file, and (2) prove it landed - not to run COPY INTO
directly. Verifying row counts here, instead of assuming the pipe worked, is what catches a broken
event notification or a malformed file before a stale/partial partition silently reaches reports.
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.utils.task_group import TaskGroup

from _common import DEFAULT_ARGS

HEAVY_TABLES_LOADED = Dataset("snowflake://RAW/heavy_tables")

# (database, schema, table, date_column) - one entry per heavy table across the 3 product DBs.
HEAVY_TABLES = [
    ("SSI_Equity", "EQUITY", "equity_trade", "trade_date"),
    ("SSI_Equity", "EQUITY", "account_balance_daily", "balance_date"),
    ("SSI_Equity", "EQUITY", "position_daily", "position_date"),
    ("SSI_Equity", "EQUITY", "margin_loan_daily", "loan_date"),
    ("SSI_Derivatives", "DERIVATIVES", "derivative_trade", "trade_date"),
    ("SSI_Derivatives", "DERIVATIVES", "account_balance_daily", "balance_date"),
    ("SSI_Derivatives", "DERIVATIVES", "position_daily", "position_date"),
    ("SSI_Derivatives", "DERIVATIVES", "margin_loan_daily", "loan_date"),
    ("SSI_OEF", "OEF", "oef_trade", "trade_date"),
    ("SSI_OEF", "OEF", "account_balance_daily", "balance_date"),
    ("SSI_OEF", "OEF", "position_daily", "position_date"),
]

LANDING_BASE_URI = {
    "EQUITY": "abfss://landing@ssidl.dfs.core.windows.net/equity",
    "DERIVATIVES": "abfss://landing@ssidl.dfs.core.windows.net/derivatives",
    "OEF": "abfss://landing@ssidl.dfs.core.windows.net/oef",
}


def export_partition(database: str, table: str, date_column: str, schema: str, **context) -> None:
    # Imported lazily so the DAG file itself has no pyodbc/pyarrow dependency at parse time.
    import sys

    sys.path.append("/opt/airflow/data-platform/scripts")
    from export_partition_to_parquet import export_partition as run_export

    partition_date = context["ds"]  # logical date of the DAG run = the partition to (re)export
    run_export(
        database=database,
        schema="raw",
        table=table,
        date_column=date_column,
        partition_date=partition_date,
        output_uri=LANDING_BASE_URI[schema],
    )


def verify_row_count(schema: str, table: str, **context) -> None:
    partition_date = context["ds"]
    hook = SnowflakeHook(snowflake_conn_id="snowflake_default")
    sql = f"""
        SELECT COUNT(*)
        FROM RAW.{schema}.{table.upper()}_RAW
        WHERE raw_data:trade_date::DATE = %s
           OR raw_data:balance_date::DATE = %s
           OR raw_data:position_date::DATE = %s
           OR raw_data:loan_date::DATE = %s
    """
    result = hook.get_first(sql, parameters=(partition_date, partition_date, partition_date, partition_date))
    row_count = result[0] if result else 0
    if row_count == 0:
        # Not necessarily an error (a day with genuinely zero OEF trades happens), but zero rows
        # for equity_trade on a trading day is almost certainly Snowpipe not having caught up yet
        # or a broken event notification - fail loudly rather than let dbt run on stale data.
        raise ValueError(
            f"RAW.{schema}.{table.upper()}_RAW has 0 rows for {partition_date} - "
            f"Snowpipe may not have ingested the exported file yet, or the export produced no data."
        )


with DAG(
    dag_id="bulk_load_heavy_tables",
    description="Export heavy trade/position/balance/margin partitions to Parquet and verify Snowpipe landed them",
    schedule="0 2 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "ingest", "snowflake", "bulk-load"],
) as dag:
    verify_tasks = []
    for database, schema, table, date_column in HEAVY_TABLES:
        with TaskGroup(group_id=f"{schema.lower()}__{table}") as tg:
            export = PythonOperator(
                task_id="export_to_parquet",
                python_callable=export_partition,
                op_kwargs={"database": database, "table": table, "date_column": date_column, "schema": schema},
                # Snowpipe auto-ingest usually lands data within ~1 minute of file arrival, but
                # give it headroom before failing the verify step on a slow event-notification day.
                execution_timeout=timedelta(minutes=15),
            )
            verify = PythonOperator(
                task_id="verify_snowpipe_landed",
                python_callable=verify_row_count,
                op_kwargs={"schema": schema, "table": table},
                retries=6,
                retry_delay=timedelta(minutes=2),  # poll for Snowpipe catch-up instead of failing immediately
                execution_timeout=timedelta(minutes=10),
            )
            export >> verify
        verify_tasks.append(tg)

    # Dataset outlet only fires after every table group (all TaskGroups) has succeeded.
    all_done = PythonOperator(
        task_id="mark_heavy_tables_loaded",
        python_callable=lambda: None,
        outlets=[HEAVY_TABLES_LOADED],
    )
    verify_tasks >> all_done
