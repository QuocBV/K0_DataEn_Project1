{{ config(materialized='table') }}

-- Silver: fund_nav_history bronze -> clean/dedup -> Iceberg silver
select
    nav_date,
    fund_id,
    nav_price,
    total_net_asset,
    outstanding_units,
    source_system,
    ingested_at
from {{ ref('bronze_fund_nav_history') }}
