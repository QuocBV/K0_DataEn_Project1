{{ config(materialized='incremental', unique_key=['account_id', 'loan_date'], on_schema_change='append_new_columns') }}

with flattened as (
    select
        raw_data:loan_date::date                       as loan_date,
        raw_data:account_id::number                    as account_id,
        raw_data:margin_loan_balance::number(20,2)      as margin_loan_balance,
        raw_data:margin_ratio::number(9,4)              as margin_ratio,
        raw_data:maintenance_margin_ratio::number(9,4)  as maintenance_margin_ratio,
        raw_data:call_margin_flag::boolean              as call_margin_flag,
        _loaded_at
    from {{ source('raw_derivatives', 'margin_loan_daily_raw') }}
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)
select *
from flattened
qualify row_number() over (
    partition by account_id, loan_date
    order by _loaded_at desc
) = 1
