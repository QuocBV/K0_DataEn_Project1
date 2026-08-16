{{ config(materialized='table') }}

-- Bronze: customer raw Parquet -> Iceberg bronze
select
    customer_code,
    customer_name,
    customer_type,
    residency,
    id_number,
    phone,
    email,
    open_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_common', 'customer') }}
