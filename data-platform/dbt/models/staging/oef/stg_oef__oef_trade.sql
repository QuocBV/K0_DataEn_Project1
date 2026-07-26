{{ config(materialized='incremental', unique_key='trade_id', on_schema_change='append_new_columns') }}

with flattened as (
    select
        raw_data:trade_id::number             as trade_id,
        raw_data:trade_date::date             as trade_date,
        raw_data:trade_datetime::timestamp_ntz as trade_datetime,
        raw_data:source_trade_id::varchar     as source_trade_id,
        raw_data:account_no::varchar          as account_no,
        raw_data:customer_code::varchar        as customer_code,
        raw_data:broker_code::varchar          as broker_code,
        raw_data:fund_id::number              as fund_id,
        raw_data:transaction_type::varchar    as transaction_type,
        raw_data:quantity_unit::number(20,4)   as quantity_unit,
        raw_data:nav_price::number(18,4)      as nav_price,
        raw_data:amount::number(20,2)         as amount,
        raw_data:fee_amount::number(18,2)     as fee_amount,
        raw_data:settlement_date::date        as settlement_date,
        raw_data:order_id::varchar            as order_id,
        raw_data:source_system::varchar       as source_system,
        raw_data:ingested_at::timestamp_ntz   as ingested_at,
        _loaded_at
    from {{ source('raw_oef', 'oef_trade_raw') }}
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)
select *
from flattened
qualify row_number() over (
    partition by source_system, source_trade_id
    order by _loaded_at desc
) = 1
