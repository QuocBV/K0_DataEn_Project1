-- Report 5: AUM (Assets Under Management) theo Khach hang / Moi gioi / Chi nhanh theo thoi gian.
-- Broker attribution uses the point-in-time customer_broker_history (who cared for the customer
-- ON balance_date), not the account's original opening broker or today's current broker - so
-- historical AUM is credited to whoever actually owned the relationship at that time.
select
    f.balance_date,
    f.product_type,
    a.customer_code,
    c.customer_name,
    cbh.broker_code,
    b.broker_name,
    b.department_id,
    b.department_name,
    b.branch_id,
    b.branch_name,
    f.account_id,
    f.cash_balance,
    f.portfolio_value,
    f.total_asset_value
from {{ ref('fact_account_balance_daily') }} f
join {{ ref('dim_account') }} a
    on a.product_type = f.product_type and a.account_id = f.account_id
join {{ ref('dim_customer') }} c on c.customer_code = a.customer_code
left join {{ ref('dim_customer_broker_history') }} cbh
    on cbh.customer_code = a.customer_code
   and f.balance_date >= cbh.valid_from
   and (cbh.valid_to is null or f.balance_date <= cbh.valid_to)
left join {{ ref('dim_broker') }} b on b.broker_code = cbh.broker_code
