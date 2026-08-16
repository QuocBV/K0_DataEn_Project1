{{ config(materialized='table') }}

-- Bronze: security raw Parquet -> Iceberg bronze
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
from {{ source('raw_equity', 'security') }}
