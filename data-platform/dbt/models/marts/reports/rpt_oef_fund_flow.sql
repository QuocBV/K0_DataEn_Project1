{{ config(materialized='table', schema='reporting') }}

select
    t.trade_date, t.fund_id, f.fund_code, f.fund_name,
    sum(case when t.transaction_type = 'SUBSCRIBE' then t.amount else 0 end) as subscribe_amount,
    sum(case when t.transaction_type = 'REDEEM' then t.amount else 0 end) as redeem_amount,
    count(distinct t.customer_code) as trading_customer_count,
    sum(case when t.transaction_type = 'SUBSCRIBE' then t.amount else 0 end)
      - sum(case when t.transaction_type = 'REDEEM' then t.amount else 0 end) as net_flow_amount
from {{ ref('fact_oef_trade') }} t
join {{ ref('dim_fund') }} f on f.fund_id = t.fund_id
group by 1,2,3,4
