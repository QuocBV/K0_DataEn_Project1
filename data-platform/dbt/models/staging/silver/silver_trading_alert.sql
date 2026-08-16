{{ config(materialized='table') }}

-- Silver: trading_alert bronze -> clean/dedup -> Iceberg silver
select
    alert_id,
    alert_date,
    customer_code,
    broker_code,
    related_product_type,
    related_source_system,
    related_trade_id,
    alert_type,
    severity,
    status,
    description,
    source_system,
    ingested_at
from {{ ref('bronze_trading_alert') }}
