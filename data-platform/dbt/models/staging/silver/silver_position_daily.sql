{{ config(materialized='table') }}

-- Silver: position_daily bronze -> clean/dedup -> Iceberg silver
select
    position_date,
    account_no,
    security_id,
    quantity,
    avg_cost_price,
    market_value,
    source_system,
    ingested_at,
    _source_db
from {{ ref('bronze_position_daily') }}
