{{ config(materialized='table') }}

-- Silver: management_commission_schedule bronze -> clean/dedup -> Iceberg silver
select
    schedule_id,
    management_level,
    commission_rate,
    effective_from,
    effective_to,
    is_current,
    source_system,
    ingested_at
from {{ ref('bronze_management_commission_schedule') }}
