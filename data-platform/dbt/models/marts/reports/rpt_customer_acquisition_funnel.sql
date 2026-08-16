{{ config(materialized='table', schema='reporting') }}

with first_trade as (
    select customer_code, min(trade_date) as first_trade_date
    from {{ ref('int_all_trades') }}
    group by 1
)
select
    year(dca.acquisition_date) as acquisition_year,
    month(dca.acquisition_date) as acquisition_month,
    dca.acquisition_channel,
    dca.campaign_code,
    dca.referral_broker_code,
    count(distinct c.customer_code) as new_customer_count,
    count(distinct case when ft.first_trade_date is not null then c.customer_code end) as converted_to_trading_count
from {{ ref('dim_customer') }} c
left join {{ source('silver', 'customer_acquisition') }} dca on dca.customer_code = c.customer_code
left join first_trade ft on ft.customer_code = c.customer_code
group by 1,2,3,4,5
