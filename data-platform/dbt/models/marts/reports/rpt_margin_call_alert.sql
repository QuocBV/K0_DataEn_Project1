-- Report 9: Canh bao margin & ty le ky quy - tai khoan dang duoi nguong duy tri hoac da bi
-- danh dau call margin.
select
    m.loan_date,
    m.product_type,
    m.account_id,
    a.account_no,
    a.customer_code,
    c.customer_name,
    c.current_broker_code,
    b.broker_name,
    m.margin_loan_balance,
    m.margin_ratio,
    m.maintenance_margin_ratio,
    m.call_margin_flag,
    case
        when m.call_margin_flag then true
        when m.margin_ratio < m.maintenance_margin_ratio then true
        else false
    end as needs_attention
from {{ ref('fact_margin_loan_daily') }} m
join {{ ref('dim_account') }} a
    on a.product_type = m.product_type and a.account_id = m.account_id
join {{ ref('dim_customer') }} c on c.customer_code = a.customer_code
left join {{ ref('dim_broker') }} b on b.broker_code = c.current_broker_code
where m.loan_date = (select max(loan_date) from {{ ref('fact_margin_loan_daily') }})
