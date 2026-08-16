{{ config(materialized='table') }}

-- Bronze: equity_trade raw Parquet -> Iceberg bronze
select
    trade_id,
    trade_date,
    trade_datetime,
    source_trade_id,
    account_no,
    customer_code,
    broker_code,
    security_id,
    market,
    side,
    order_type,
    quantity,
    price,
    amount,
    fee_amount,
    tax_amount,
    settlement_date,
    order_id,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_equity', 'equity_trade') }}
