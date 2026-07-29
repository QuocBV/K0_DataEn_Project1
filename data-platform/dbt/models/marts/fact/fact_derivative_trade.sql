{{
    config(
        materialized='incremental',
        unique_key=['source_system', 'source_trade_id'],
        on_schema_change='append_new_columns'
    )
}}

select
    'DERIVATIVES' as product_type,
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
    ingested_at
from {{ source('silver', 'derivative_trade') }}

{% if is_incremental() %}
where ingested_at > (select coalesce(max(ingested_at), '1900-01-01') from {{ this }})
{% endif %}