{{
    config(
        materialized='incremental',
        unique_key=['source_system', 'source_trade_id'],
        on_schema_change='append_new_columns'
    )
}}

select
    'EQUITY' as product_type,
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
    ingested_at
from {{ ref('stg_equity__equity_trade') }}

{% if is_incremental() %}
where ingested_at > (select coalesce(max(ingested_at), '1900-01-01') from {{ this }})
{% endif %}
