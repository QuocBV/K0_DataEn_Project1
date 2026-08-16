{{ config(materialized='table') }}

-- Bronze: customer_complaint raw Parquet -> Iceberg bronze
select
    complaint_id,
    customer_code,
    broker_code,
    complaint_date,
    channel,
    category,
    status,
    resolution_date,
    description,
    source_system,
    ingested_at
from {{ source('raw_common', 'customer_complaint') }}
