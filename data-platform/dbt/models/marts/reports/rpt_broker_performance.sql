-- Report 3: Danh gia CTV/Moi gioi - so KH dang quan ly, doanh so/KH, ty le KH van con giao dich
-- (proxy cho retention: co giao dich trong 90 ngay gan nhat).
with managed_customers as (
    select broker_code, count(distinct customer_code) as managed_customer_count
    from {{ ref('dim_customer_broker_history') }}
    where is_current
    group by broker_code
),

trade_activity as (
    select
        broker_code,
        count(distinct customer_code) as trading_customer_count,
        count(distinct case when trade_date >= dateadd(day, -90, current_date()) then customer_code end)
            as active_last_90d_customer_count,
        sum(amount)     as total_trade_amount,
        sum(fee_amount) as total_fee_revenue
    from {{ ref('int_all_trades') }}
    group by broker_code
)

select
    b.broker_code,
    b.broker_name,
    b.broker_type,
    b.department_name,
    b.branch_name,
    coalesce(mc.managed_customer_count, 0)              as managed_customer_count,
    coalesce(ta.trading_customer_count, 0)               as trading_customer_count,
    coalesce(ta.active_last_90d_customer_count, 0)        as active_last_90d_customer_count,
    div0(ta.active_last_90d_customer_count, nullif(mc.managed_customer_count, 0)) as retention_ratio_90d,
    coalesce(ta.total_trade_amount, 0)                    as total_trade_amount,
    coalesce(ta.total_fee_revenue, 0)                     as total_fee_revenue,
    div0(ta.total_fee_revenue, nullif(mc.managed_customer_count, 0)) as fee_revenue_per_customer
from {{ ref('dim_broker') }} b
left join managed_customers mc on mc.broker_code = b.broker_code
left join trade_activity ta on ta.broker_code = b.broker_code
