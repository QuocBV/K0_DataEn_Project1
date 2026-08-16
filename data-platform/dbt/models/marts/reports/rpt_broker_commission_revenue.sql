{{ config(materialized='table', schema='reporting') }}

select
    t.trade_date,
    t.product_type,
    t.broker_code,
    b.broker_name,
    b.department_id,
    b.department_name,
    b.branch_id,
    b.branch_name,
    count(distinct t.trade_id) as trade_count,
    sum(t.amount) as trade_amount,
    sum(t.fee_amount) as fee_revenue,
    sum(t.fee_amount * fs.commission_rate) as broker_commission_amount
from {{ ref('int_all_trades') }} t
join {{ ref('dim_broker') }} b on b.broker_code = t.broker_code
join {{ ref('dim_fee_schedule') }} fs
    on fs.product_type = t.product_type
    and t.trade_date >= fs.effective_from
    and (fs.effective_to is null or t.trade_date <= fs.effective_to)
group by 1,2,3,4,5,6,7,8
