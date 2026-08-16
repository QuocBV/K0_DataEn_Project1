{{ config(materialized='table', schema='reporting') }}

with base as (
    select department_id, department_name, branch_id, branch_name,
           sum(trade_amount) as total_trade_amount,
           sum(fee_revenue) as total_fee_revenue,
           count(distinct broker_code) as broker_count,
           sum(trade_count) as total_trade_count
    from {{ ref('rpt_broker_commission_revenue') }}
    group by 1,2,3,4
)
select *,
       rank() over (order by total_fee_revenue desc) as revenue_rank,
       rank() over (order by total_trade_amount desc) as trade_rank
from base
