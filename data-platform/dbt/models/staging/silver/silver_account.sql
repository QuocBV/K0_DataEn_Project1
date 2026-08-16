{{ config(materialized='table') }}

-- Silver: account bronze -> clean/dedup -> Iceberg silver
select
    account_id,
    account_no,
    customer_code,
    broker_code,
    product_type,
    open_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ ref('bronze_account') }}
