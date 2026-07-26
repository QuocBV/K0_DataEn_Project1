{{ config(materialized='incremental', unique_key=['account_id', 'security_id', 'position_date'], on_schema_change='append_new_columns') }}

with flattened as (
    select
        raw_data:position_date::date        as position_date,
        raw_data:account_id::number         as account_id,
        raw_data:security_id::number        as security_id,
        raw_data:quantity::number(20,4)      as quantity,
        raw_data:avg_cost_price::number(18,4) as avg_cost_price,
        raw_data:market_value::number(20,2)  as market_value,
        _loaded_at
    from {{ source('raw_equity', 'position_daily_raw') }}
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)
select *
from flattened
qualify row_number() over (
    partition by account_id, security_id, position_date
    order by _loaded_at desc
) = 1
