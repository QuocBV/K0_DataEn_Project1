{{ config(materialized='table') }}

-- Silver: security bronze -> clean/dedup -> Iceberg silver
select
    security_id,
    symbol,
    security_name,
    exchange,
    sector,
    security_type,
    listing_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ ref('bronze_security') }}
