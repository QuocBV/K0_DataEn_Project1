{{ config(materialized='table') }}

-- Bronze: fee_schedule raw Parquet -> Iceberg bronze
select
    fee_schedule_id,
    product_type,
    broker_tier,
    fee_rate,
    commission_rate,
    effective_from,
    effective_to,
    is_current,
    source_system,
    ingested_at
from {{ source('raw_common', 'fee_schedule') }}
