{{ config(materialized='table') }}

-- Silver: fee_schedule bronze -> clean/dedup -> Iceberg silver
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
from {{ ref('bronze_fee_schedule') }}
