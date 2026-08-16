{{ config(materialized='table') }}

-- Silver: daily_price bronze -> clean/dedup -> Iceberg silver
select
    price_date,
    security_id,
    close_price,
    reference_price,
    ceiling_price,
    floor_price,
    volume,
    source_system,
    ingested_at
from {{ ref('bronze_daily_price') }}
