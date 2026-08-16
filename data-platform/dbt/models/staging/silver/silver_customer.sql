{{ config(materialized='table') }}

-- Silver: customer bronze -> clean/dedup -> Iceberg silver
select
    customer_code,
    customer_name,
    customer_type,
    residency,
    phone,
    email,
    open_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at,
    upper(trim(customer_code)) as customer_code
from {{ ref('bronze_customer') }}
