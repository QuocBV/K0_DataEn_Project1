{{ config(materialized='table') }}

-- Silver: market_index_price bronze -> clean/dedup -> Iceberg silver
select
    price_date,
    index_code,
    close_value,
    change_percent,
    volume,
    source_system,
    ingested_at
from {{ ref('bronze_market_index_price') }}
