{{ config(materialized='table', schema='reporting') }}

select
    m.product_type, m.account_no, a.customer_code, c.customer_name,
    a.broker_code, b.broker_name,
    m.margin_loan_balance, m.margin_ratio, m.maintenance_margin_ratio,
    m.loan_date as alert_date
from {{ ref('fact_margin_loan_daily') }} m
join {{ ref('dim_account') }} a on a.account_no = m.account_no
join {{ ref('dim_customer') }} c on c.customer_code = a.customer_code
left join {{ ref('dim_broker') }} b on b.broker_code = a.broker_code
where m.call_margin_flag
