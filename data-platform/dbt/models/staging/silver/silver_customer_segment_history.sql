{{ config(materialized='table') }}

-- Silver: customer_segment_history bronze -> clean/dedup -> Iceberg silver
select
    history_id,
    customer_code,
    segment,
    valid_from,
    valid_to,
    is_current,
    source_system,
    ingested_at
from {{ ref('bronze_customer_segment_history') }}
