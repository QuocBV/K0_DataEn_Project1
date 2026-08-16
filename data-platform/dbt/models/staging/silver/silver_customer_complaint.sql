{{ config(materialized='table') }}

-- Silver: customer_complaint bronze -> clean/dedup -> Iceberg silver
select
    complaint_id,
    customer_code,
    broker_code,
    complaint_date,
    channel,
    category,
    status,
    resolution_date,
    description,
    source_system,
    ingested_at
from {{ ref('bronze_customer_complaint') }}
