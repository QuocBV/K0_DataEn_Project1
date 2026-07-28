{{ config(materialized='incremental', unique_key='trade_id', on_schema_change='append_new_columns') }}

{#- Flattens the VARIANT landing table (see snowflake/02_variant_landing_util.sql) into typed
    columns, and de-duplicates on the natural source key: a corrected/re-exported partition file
    lands as additional rows rather than replacing the old ones (Snowpipe only appends), so the
    latest _loaded_at per (source_system, source_trade_id) wins here.
    Incremental (not a view): re-parsing VARIANT for millions of rows on every downstream query
    would be wasted work at this volume - materialize once here, only re-scanning rows landed
    since the last run, and let fact_equity_trade's own incremental step build on top of this. #}
with flattened as (
    select
        raw_data:trade_id::number             as trade_id,
        raw_data:trade_date::date             as trade_date,
        raw_data:trade_datetime::timestamp_ntz as trade_datetime,
        raw_data:source_trade_id::varchar     as source_trade_id,
        raw_data:account_no::varchar          as account_no,
        raw_data:customer_code::varchar        as customer_code,
        raw_data:broker_code::varchar          as broker_code,
        raw_data:security_id::number          as security_id,
        raw_data:market::varchar              as market,
        raw_data:side::varchar                as side,
        raw_data:order_type::varchar          as order_type,
        raw_data:quantity::number             as quantity,
        raw_data:price::number(18,2)          as price,
        raw_data:amount::number(20,2)         as amount,
        raw_data:fee_amount::number(18,2)     as fee_amount,
        raw_data:tax_amount::number(18,2)     as tax_amount,
        raw_data:settlement_date::date        as settlement_date,
        raw_data:order_id::varchar            as order_id,
        raw_data:source_system::varchar       as source_system,
        raw_data:ingested_at::timestamp_ntz   as ingested_at,
        _loaded_at
    from {{ source('raw_equity', 'equity_trade_raw') }}
)
select * exclude (_loaded_at)
from flattened
qualify row_number() over (
    partition by source_system, source_trade_id
    order by _loaded_at desc
) = 1