"""Dagster assets: Airbyte raw ingest, dbt transform (bronze->silver->gold->reporting), Soda quality."""
import os, subprocess
from dagster import asset, AssetSelection
from dagster_airbyte import AirbyteResource
from dagster_dbt import dbt_assets, DbtCliResource, DbtManifestAssetSelection
from resources import airbyte_resource, dbt_resource, AIRBYTE_CONNECTION_IDS

DBT_PROJECT = "/opt/airflow/data-platform/dbt"
SODA_DIR = "/opt/airflow/data-platform/soda"


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

# dbt assets - one continuous dbt project, selected by tag so Dagster models the layered DAG.
# Run order inside dbt is handled by model dependencies (bronze -> silver -> gold -> reporting).
# Note: requires dbt deps + dbt parse (target/manifest.json) to have been generated first.

@dbt_assets(manifest=os.path.join(DBT_PROJECT, "target", "manifest.json"))
def all_dbt_assets(context, dbt: DbtCliResource):
    yield from dbt.cli(["run", "--models", "tag:bronze"], context=context)
    yield from dbt.cli(["run", "--models", "tag:silver"], context=context)
    yield from dbt.cli(["run", "--models", "tag:dimension tag:fact"], context=context)
    yield from dbt.cli(["run", "--models", "tag:report"], context=context)


@asset(key_prefix=["quality"], name="bronze_checked", deps=[raw_common, raw_equity, raw_deriv, raw_oef])
def bronze_checked(_):
    return _soda("bronze/bronze_quality.yml")


@asset(key_prefix=["quality"], name="silver_checked", deps=[all_dbt_assets])
def silver_checked(_):
    return _soda("silver/silver_quality.yml")


@asset(key_prefix=["quality"], name="gold_checked", deps=[all_dbt_assets])
def gold_checked(_):
    return _soda("gold/gold_quality.yml")