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

# Airbyte raw assets are auto-discovered from Airbyte API (one asset per MSSQL connection).
ingest_raw_job = define_asset_job(
    "ingest_raw",
    selection=AssetSelection.groups("mssql"),
)
main_pipeline_job = define_asset_job("main_pipeline", selection=AssetSelection.all())
soda_job = define_asset_job("soda_quality", selection=AssetSelection.groups("quality"))
dbt_job = define_asset_job("dbt_transform", selection=AssetSelection.assets(assets_mod.all_dbt_assets))

# Daily pipeline: Airbyte ingest -> dbt transform -> quality
daily_schedule = ScheduleDefinition(
    job=main_pipeline_job,
    cron_schedule="0 3 * * *",
    default_status=DefaultScheduleStatus.RUNNING,
)

defs = Definitions(
    assets=[
        *assets_mod.raw_assets,
        assets_mod.all_dbt_assets,
        assets_mod.bronze_checked,
        assets_mod.silver_checked,
        assets_mod.gold_checked,
    ],
    resources={"airbyte": airbyte_resource, "dbt": dbt_resource},
    jobs=[ingest_raw_job, main_pipeline_job, dbt_job, soda_job],
    schedules=[daily_schedule],
)
