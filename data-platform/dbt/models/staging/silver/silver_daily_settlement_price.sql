{{ config(materialized='table') }}

-- Silver: daily_settlement_price bronze -> clean/dedup -> Iceberg silver
select
    price_date,
    contract_id,
    settlement_price,
    open_interest,
    volume,
    source_system,
    ingested_at
from {{ ref('bronze_daily_settlement_price') }}
