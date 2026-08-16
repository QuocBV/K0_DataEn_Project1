{{ config(materialized='table') }}

-- Silver: customer_acquisition bronze -> clean/dedup -> Iceberg silver
select
    customer_code,
    acquisition_channel,
    referral_broker_code,
    acquisition_date,
    campaign_code,
    source_system,
    ingested_at
from {{ ref('bronze_customer_acquisition') }}
