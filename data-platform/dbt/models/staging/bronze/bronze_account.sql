{{ config(materialized='table') }}

-- Bronze: account raw Parquet -> Iceberg bronze
select
    account_id,
    account_no,
    customer_code,
    broker_code,
    product_type,
    open_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_common', 'account') }}
