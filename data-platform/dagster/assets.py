"""Dagster assets: Airbyte raw ingest (auto-discovered via API), dbt transform, Soda quality."""
import os, subprocess
from dagster import asset, AssetSelection, AssetsDefinition, multi_asset
from dagster_airbyte import AirbyteResource
from dagster_dbt import dbt_assets, DbtCliResource, DbtManifestAssetSelection
from resources import airbyte_resource, dbt_resource, mssql_connections

DBT_PROJECT = "/opt/airflow/data-platform/dbt"
SODA_DIR = "/opt/airflow/data-platform/soda"


# ---- Airbyte raw assets: one asset per MSSQL connection discovered from Airbyte API ----
import re

def _sanitize(name):
    # Dagster asset names: lowercase letters, digits, underscore; must not start with digit.
    s = name.lower()
    s = re.sub(r"[^a-z0-9_]+", "_", s)
    s = s.strip("_")
    if not s or s[0].isdigit():
        s = "conn_" + s
    return s


def _make_sync_asset(name, connection_id):
    safe = _sanitize(name)

    @asset(key_prefix=["s3", "raw"], name=safe, group_name="mssql", required_resource_keys={"airbyte"})
    def _sync(context):
        context.resources.airbyte.sync_connection(connection_id=connection_id)
        return True
    return _sync


# Discover connections at definition-build time (list from Airbyte API)
_discovered = mssql_connections()
_raw_asset_list = []
for _idx, _conn in enumerate(_discovered):
    _raw_asset_list.append(_make_sync_asset(_conn["name"] or f"mssql_conn_{_idx}", _conn["connection_id"]))

# If no connections found (Airbyte down at startup), fall back to empty - Dagster still loads
if not _raw_asset_list:
    @asset(key_prefix=["s3", "raw"], name="no_mssql_connections", group_name="mssql")
    def _empty_conn(context):
        raise RuntimeError("No MSSQL connections discovered on Airbyte - check connections (sources MSSQL -> S3)")
    _raw_asset_list.append(_empty_conn)

raw_assets = _raw_asset_list


# ---- dbt assets ----
@dbt_assets(manifest=os.path.join(DBT_PROJECT, "target", "manifest.json"))
def all_dbt_assets(context, dbt: DbtCliResource):
    yield from dbt.cli(["run", "--models", "tag:bronze"], context=context)
    yield from dbt.cli(["run", "--models", "tag:silver"], context=context)
    yield from dbt.cli(["run", "--models", "tag:dimension tag:fact"], context=context)
    yield from dbt.cli(["run", "--models", "tag:report"], context=context)


# ---- Soda quality ----
def _soda(checks):
    cmd = ["soda", "scan", "-d", "ssi_trino", "-c", os.path.join(SODA_DIR, "configuration.yml"),
           os.path.join(SODA_DIR, "checks", checks)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout


@asset(key_prefix=["quality"], name="bronze_checked", group_name="quality")
def bronze_checked(_):
    return _soda("bronze/bronze_quality.yml")


@asset(key_prefix=["quality"], name="silver_checked", deps=[all_dbt_assets], group_name="quality")
def silver_checked(_):
    return _soda("silver/silver_quality.yml")


@asset(key_prefix=["quality"], name="gold_checked", deps=[all_dbt_assets], group_name="quality")
def gold_checked(_):
    return _soda("gold/gold_quality.yml")