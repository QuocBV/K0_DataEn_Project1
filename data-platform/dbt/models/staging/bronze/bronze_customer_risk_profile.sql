{{ config(materialized='table') }}

-- Bronze: customer_risk_profile raw Parquet -> Iceberg bronze
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
from {{ source('raw_common', 'customer_risk_profile') }}
