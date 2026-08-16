{{ config(materialized='table', schema='reporting') }}

with last_trade as (
    select customer_code, max(trade_date) as last_trade_date
    from {{ ref('int_all_trades') }}
    group by 1
)
select c.customer_code, c.customer_name, c.customer_type,
       lt.last_trade_date,
       coalesce(date_diff('day', lt.last_trade_date, current_date), 999) as days_since_last_trade,
       current_date as as_of_date
from {{ ref('dim_customer') }} c
left join last_trade lt on lt.customer_code = c.customer_code
where coalesce(date_diff('day', lt.last_trade_date, current_date), 999) >= 90
