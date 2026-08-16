{{ config(materialized='table') }}

-- Bronze: fund_nav_history raw Parquet -> Iceberg bronze
select
    nav_date,
    fund_id,
    nav_price,
    total_net_asset,
    outstanding_units,
    source_system,
    ingested_at
from {{ source('raw_oef', 'fund_nav_history') }}
