{{ config(materialized='table', schema='reporting') }}

with cmv as (
    select a.customer_code,
           year(b.balance_date) as value_year,
           month(b.balance_date) as value_month,
           min_by(b.total_asset_value, b.balance_date) as start_value,
           max_by(b.total_asset_value, b.balance_date) as end_value
    from {{ ref('fact_account_balance_daily') }} b
    join {{ ref('dim_account') }} a on a.account_no = b.account_no
    group by 1,2,3
),
vi as (
    select year(price_date) as value_year,
           month(price_date) as value_month,
           min_by(close_value, price_date) as start_index,
           max_by(close_value, price_date) as end_index
    from {{ source('silver', 'market_index_price') }}
    where index_code = 'VNINDEX'
    group by 1,2
)
select cmv.customer_code, cmv.value_year, cmv.value_month,
       cmv.start_value, cmv.end_value,
       (cmv.end_value - cmv.start_value) / cmv.start_value as customer_return_pct,
       (vi.end_index - vi.start_index) / vi.start_index as vnindex_return_pct
from cmv
join vi on vi.value_year = cmv.value_year and vi.value_month = cmv.value_month
