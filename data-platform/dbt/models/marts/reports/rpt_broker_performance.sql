{{ config(materialized='table', schema='reporting') }}

with trades as (
    select broker_code, customer_code, trade_id, amount
    from {{ ref('fact_equity_trade') }}
    union all
    select broker_code, customer_code, trade_id, amount
    from {{ ref('fact_derivative_trade') }}
    union all
    select broker_code, customer_code, trade_id, amount
    from {{ ref('fact_oef_trade') }}
),
cust_counts as (
    select broker_code,
           count(distinct customer_code) as customer_count,
           count(trade_id) as trade_count,
           sum(amount) as total_amount
    from trades
    group by 1
)
select b.broker_code, b.broker_name, b.broker_type,
       b.department_name, b.branch_name,
       coalesce(c.customer_count,0) as customer_count,
       coalesce(c.trade_count,0) as trade_count,
       coalesce(c.total_amount,0) as total_amount,
       case when c.customer_count > 0 then c.total_amount / c.customer_count else 0 end as amount_per_customer
from {{ ref('dim_broker') }} b
left join cust_counts c on c.broker_code = b.broker_code
