"""Dagster Definitions: gắn resources + assets + jobs + schedules."""
from dagster import (
    Definitions,
    ScheduleDefinition,
    AssetSelection,
    define_asset_job,
    DefaultScheduleStatus,
)
import assets as assets_mod
from resources import airbyte_resource, dbt_resource

ingest_raw_assets = [
    assets_mod.raw_common,
    assets_mod.raw_equity,
    assets_mod.raw_deriv,
    assets_mod.raw_oef,
]
ingest_raw_job = define_asset_job("ingest_raw", selection=AssetSelection.assets(*ingest_raw_assets))
main_pipeline_job = define_asset_job("main_pipeline", selection=AssetSelection.all())
generate_trades_job = define_asset_job("generate_trades", selection=AssetSelection.keys(["bronze", "bronze_done"]))
soda_job = define_asset_job("soda_quality", selection=AssetSelection.groups("quality"))

generate_schedule = ScheduleDefinition(
    job=generate_trades_job,
    cron_schedule="0 6 * * *",
    default_status=DefaultScheduleStatus.RUNNING,
)

defs = Definitions(
    assets=[
        assets_mod.raw_common,
        assets_mod.raw_equity,
        assets_mod.raw_deriv,
        assets_mod.raw_oef,
        assets_mod.bronze_done,
        assets_mod.silver_done,
        assets_mod.bronze_checked,
        assets_mod.silver_checked,
        assets_mod.gold_checked,
        assets_mod.gold_dbt_assets,
        assets_mod.reporting_dbt_assets,
        assets_mod.commission_done,
    ],
    resources={"airbyte": airbyte_resource, "dbt": dbt_resource},
    jobs=[ingest_raw_job, main_pipeline_job, generate_trades_job, soda_job],
    schedules=[generate_schedule],
)