-- Report 4: Hieu qua giao dich - turnover, tan suat, gia tri TB/lenh theo khach hang/san pham/thang.
select
    year(t.trade_date)  as trade_year,
    month(t.trade_date) as trade_month,
    t.product_type,
    t.customer_code,
    c.customer_name,
    c.current_segment,
    count(distinct t.trade_id)          as trade_count,
    count(distinct t.trade_date)        as trading_days,
    sum(t.amount)                       as turnover_amount,
    div0(sum(t.amount), nullif(count(distinct t.trade_id), 0)) as avg_amount_per_trade
from {{ ref('int_all_trades') }} t
join {{ ref('dim_customer') }} c on c.customer_code = t.customer_code
group by 1, 2, 3, 4, 5, 6
