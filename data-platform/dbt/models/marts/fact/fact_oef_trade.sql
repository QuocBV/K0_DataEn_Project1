{{
    config(
        materialized='incremental',
        unique_key=['source_system', 'source_trade_id'],
        on_schema_change='append_new_columns'
    )
}}

select
    'OEF' as product_type,
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
    ingested_at
from {{ ref('stg_oef__oef_trade') }}

{% if is_incremental() %}
where ingested_at > (select coalesce(max(ingested_at), '1900-01-01') from {{ this }})
{% endif %}