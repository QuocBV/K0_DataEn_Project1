{{ config(materialized='table') }}

-- Silver: derivative_contract bronze -> clean/dedup -> Iceberg silver
select
    contract_id,
    contract_code,
    underlying_symbol,
    contract_type,
    multiplier,
    listing_date,
    maturity_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ ref('bronze_derivative_contract') }}
