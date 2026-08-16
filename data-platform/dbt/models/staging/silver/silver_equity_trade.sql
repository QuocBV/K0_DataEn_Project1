{{ config(materialized='table') }}

-- Silver: equity_trade bronze -> clean/dedup -> Iceberg silver
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
    ingested_at,
    upper(trim(customer_code)) as customer_code,
    upper(trim(broker_code)) as broker_code,
    upper(trim(side)) as side,
    upper(trim(source_system)) as source_system
from {{ ref('bronze_equity_trade') }}
