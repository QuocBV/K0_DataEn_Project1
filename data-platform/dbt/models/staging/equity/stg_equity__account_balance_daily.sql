{{ config(materialized='incremental', unique_key=['account_id', 'balance_date'], on_schema_change='append_new_columns') }}

with flattened as (
    select
        raw_data:balance_date::date        as balance_date,
        raw_data:account_id::number        as account_id,
        raw_data:cash_balance::number(20,2) as cash_balance,
        raw_data:portfolio_value::number(20,2) as portfolio_value,
        raw_data:total_asset_value::number(20,2) as total_asset_value,
        _loaded_at
    from {{ source('raw_equity', 'account_balance_daily_raw') }}
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)
select *
from flattened
qualify row_number() over (
    partition by account_id, balance_date
    order by _loaded_at desc
) = 1
