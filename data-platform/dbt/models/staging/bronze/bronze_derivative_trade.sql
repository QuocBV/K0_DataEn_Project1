{{ config(materialized='table') }}

-- Bronze: derivative_trade raw Parquet -> Iceberg bronze
select
    trade_id,
    trade_date,
    trade_datetime,
    source_trade_id,
    account_no,
    customer_code,
    broker_code,
    contract_id,
    position_side,
    order_action,
    quantity,
    price,
    amount,
    margin_amount,
    fee_amount,
    settlement_date,
    order_id,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_derivatives', 'derivative_trade') }}
