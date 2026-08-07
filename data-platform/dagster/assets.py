"""Dagster assets: Airbyte raw, Spark ETL, Soda, dbt Gold/Reporting."""
import os, subprocess
from dagster import asset, op, AssetSelection
from dagster_airbyte import AirbyteResource
from dagster_dbt import dbt_assets, DbtCliResource, DbtManifestAssetSelection
from resources import airbyte_resource, dbt_resource, AIRBYTE_CONNECTION_IDS

DBT_PROJECT = "/opt/airflow/data-platform/dbt"
SODA_DIR = "/opt/airflow/data-platform/soda"
SPARK_DIR = "/opt/airflow/data-platform/spark/jobs"
SPARK_MASTER = os.getenv("SPARK_MASTER", "spark://spark-master:7077")


def _spark(job, script, *args):
    cmd = ["spark-submit", "--master", SPARK_MASTER, script] + list(args)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout


def _soda(checks):
    cmd = ["soda", "scan", "-d", "ssi_trino", "-c", os.path.join(SODA_DIR, "configuration.yml"),
           os.path.join(SODA_DIR, "checks", checks)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout


# Airbyte raw assets (one per connection set in UI)
def _raw(prefix, conn_key):
    @asset(key_prefix=["s3", "raw"], name=f"{prefix}_raw", required_resource_keys={"airbyte"})
    def _a(context):
        context.resources.airbyte.sync_connection(connection_id=AIRBYTE_CONNECTION_IDS[conn_key])
        return True
    return _a


raw_common = _raw("common", "mssql_common_to_s3")
raw_equity = _raw("equity", "mssql_equity_to_s3")
raw_deriv = _raw("derivatives", "mssql_derivatives_to_s3")
raw_oef = _raw("oef", "mssql_oef_to_s3")


@asset(key_prefix=["bronze"], name="bronze_done", deps=[raw_common, raw_equity, raw_deriv, raw_oef])
def bronze_done(context):
    for src in ["common", "equity", "derivatives", "oef", "hr"]:
        _spark("bronze_etl", os.path.join(SPARK_DIR, "bronze_etl.py"), "--date", context.run_config.get("date", "2027-01-01"), "--source", src)
    return True


@asset(key_prefix=["silver"], name="silver_done", deps=[bronze_done])
def silver_done(context):
    _spark("silver_etl", os.path.join(SPARK_DIR, "silver_etl.py"), "--date", context.run_config.get("date", "2027-01-01"))
    return True


@asset(key_prefix=["quality"], name="bronze_checked", deps=[bronze_done])
def bronze_checked(_):
    return _soda("bronze/bronze_quality.yml")


@asset(key_prefix=["quality"], name="silver_checked", deps=[silver_done])
def silver_checked(_):
    return _soda("silver/silver_quality.yml")


# dbt Gold + Reporting (Trino) - requires target/manifest.json
@dbt_assets(manifest=os.path.join(DBT_PROJECT, "target", "manifest.json"),
            select=AssetSelection.all().to_selector_string() if False else "path:models/marts")
def gold_dbt_assets(context, dbt: DbtCliResource):
    yield from dbt.cli(["run", "--select", "path:models/marts", "--exclude", "dim_customer_history"], context=context)
    yield from dbt.cli(["snapshot"], context=context)
    yield from dbt.cli(["run", "--select", "dim_customer_history"], context=context)


@dbt_assets(manifest=os.path.join(DBT_PROJECT, "target", "manifest.json"), select="path:models/marts/reports")
def reporting_dbt_assets(context, dbt: DbtCliResource):
    yield from dbt.cli(["run", "--select", "path:models/marts/reports"], context=context)


@asset(key_prefix=["reporting"], name="commission_done", deps=[gold_dbt_assets])
def commission_done(context):
    _spark("commission_engine", os.path.join(SPARK_DIR, "commission_engine.py"), "--date", context.run_config.get("date", "2027-01-01"))
    return True


@asset(key_prefix=["quality"], name="gold_checked", deps=[gold_dbt_assets, commission_done])
def gold_checked(_):
    return _soda("gold/gold_quality.yml")