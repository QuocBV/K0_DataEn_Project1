{{ config(materialized='table') }}

-- Silver: customer_risk_profile bronze -> clean/dedup -> Iceberg silver
select
    history_id,
    customer_code,
    investor_classification,
    risk_level,
    valid_from,
    valid_to,
    is_current,
    source_system,
    ingested_at
from {{ ref('bronze_customer_risk_profile') }}
