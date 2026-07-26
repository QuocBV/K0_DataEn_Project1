-- Report 2: Xep hang Phong ban / Chi nhanh theo doanh so, so KH active va ty trong san pham,
-- theo thang - dung de danh gia hieu qua don vi kinh doanh.
select
    year(t.trade_date)   as trade_year,
    month(t.trade_date)  as trade_month,
    b.branch_id,
    b.branch_name,
    b.department_id,
    b.department_name,
    t.product_type,
    count(distinct t.trade_id)     as trade_count,
    count(distinct t.customer_code) as active_customer_count,
    sum(t.amount)                  as trade_amount,
    sum(t.fee_amount)              as fee_revenue
from {{ ref('int_all_trades') }} t
join {{ ref('dim_broker') }} b on b.broker_code = t.broker_code
group by 1, 2, 3, 4, 5, 6, 7
