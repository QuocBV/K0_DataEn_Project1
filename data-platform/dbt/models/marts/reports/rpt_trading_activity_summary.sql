{{ config(materialized='table', schema='reporting') }}

with trades as (
    select 'EQUITY' as product_type, trade_id, customer_code, amount, fee_amount from {{ ref('fact_equity_trade') }}
    union all
    select 'DERIVATIVES' as product_type, trade_id, customer_code, amount, fee_amount from {{ ref('fact_derivative_trade') }}
    union all
    select 'OEF' as product_type, trade_id, customer_code, amount, fee_amount from {{ ref('fact_oef_trade') }}
)
select product_type,
       count(trade_id) as trade_count,
       count(distinct customer_code) as customer_count,
       sum(amount) as total_amount,
       sum(fee_amount) as total_fee
from trades
group by 1
