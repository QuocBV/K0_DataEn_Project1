{{ config(materialized='table') }}

-- Bronze: market_index_price raw Parquet -> Iceberg bronze
select
    price_date,
    index_code,
    close_value,
    change_percent,
    volume,
    source_system,
    ingested_at
from {{ source('raw_common', 'market_index_price') }}
