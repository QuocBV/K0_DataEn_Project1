{{ config(materialized='table') }}

-- Bronze: oef_trade raw Parquet -> Iceberg bronze
select
    trade_id,
    trade_date,
    trade_datetime,
    source_trade_id,
    account_no,
    customer_code,
    broker_code,
    fund_id,
    transaction_type,
    quantity_unit,
    nav_price,
    amount,
    fee_amount,
    settlement_date,
    order_id,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_oef', 'oef_trade') }}
