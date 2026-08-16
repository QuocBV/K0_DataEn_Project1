{{ config(materialized='table') }}

-- Bronze: trading_alert raw Parquet -> Iceberg bronze
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
from {{ source('raw_common', 'trading_alert') }}
