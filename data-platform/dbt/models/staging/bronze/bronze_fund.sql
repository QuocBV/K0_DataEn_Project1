{{ config(materialized='table') }}

-- Bronze: fund raw Parquet -> Iceberg bronze
select
    fund_id,
    fund_code,
    fund_name,
    fund_type,
    fund_manager,
    inception_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_oef', 'fund') }}
