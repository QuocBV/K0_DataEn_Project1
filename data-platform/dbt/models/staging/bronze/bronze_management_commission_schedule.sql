{{ config(materialized='table') }}

-- Bronze: management_commission_schedule raw Parquet -> Iceberg bronze
select
    schedule_id,
    management_level,
    commission_rate,
    effective_from,
    effective_to,
    is_current,
    source_system,
    ingested_at
from {{ source('raw_common', 'management_commission_schedule') }}
