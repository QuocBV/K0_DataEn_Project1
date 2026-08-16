{{ config(materialized='table') }}

-- Bronze: daily_settlement_price raw Parquet -> Iceberg bronze
select
    price_date,
    contract_id,
    settlement_price,
    open_interest,
    volume,
    source_system,
    ingested_at
from {{ source('raw_derivatives', 'daily_settlement_price') }}
