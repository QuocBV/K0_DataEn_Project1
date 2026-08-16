{{ config(materialized='table') }}

-- Bronze: daily_price raw Parquet -> Iceberg bronze
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
from {{ source('raw_equity', 'daily_price') }}
