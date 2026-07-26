-- Report 7: Khach hang dormant/churn - khong phat sinh giao dich trong 90 ngay gan nhat.
with last_trade as (
    select customer_code, max(trade_date) as last_trade_date
    from {{ ref('int_all_trades') }}
    group by customer_code
)

select
    c.customer_code,
    c.customer_name,
    c.current_segment,
    c.current_broker_code,
    b.broker_name  as current_broker_name,
    lt.last_trade_date,
    datediff(day, lt.last_trade_date, current_date()) as days_since_last_trade,
    case
        when lt.last_trade_date is null then true
        when datediff(day, lt.last_trade_date, current_date()) >= 90 then true
        else false
    end as is_dormant
from {{ ref('dim_customer') }} c
left join last_trade lt on lt.customer_code = c.customer_code
left join {{ ref('dim_broker') }} b on b.broker_code = c.current_broker_code
where c.is_active
