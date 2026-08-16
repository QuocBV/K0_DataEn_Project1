{{ config(materialized='table', schema='reporting') }}

select
    b.balance_date,
    ch.broker_code,
    br.broker_name,
    br.branch_id,
    br.branch_name,
    sum(b.total_asset_value) as total_aum,
    count(distinct a.customer_code) as customer_count
from {{ ref('fact_account_balance_daily') }} b
join {{ ref('dim_account') }} a on a.account_no = b.account_no
join {{ ref('dim_customer_broker_history') }} ch
    on ch.customer_code = a.customer_code and ch.is_current
join {{ ref('dim_broker') }} br on br.broker_code = ch.broker_code
group by 1,2,3,4,5
