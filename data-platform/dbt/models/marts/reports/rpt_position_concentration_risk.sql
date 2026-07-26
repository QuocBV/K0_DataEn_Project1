-- Report 8: Rui ro tap trung danh muc - % gia tri 1 ma CK/hop dong/quy tren tong danh muc cua
-- tung khach hang tai moi ngay, va tong gia tri toan cong ty dang nam giu theo tung ma (rui ro he
-- thong neu 1 ma bi giam gia sau).
with position_with_customer as (
    select
        p.position_date,
        p.product_type,
        p.instrument_id,
        p.market_value,
        a.customer_code
    from {{ ref('fact_position_daily') }} p
    join {{ ref('dim_account') }} a
        on a.product_type = p.product_type and a.account_id = p.account_id
),

customer_portfolio_total as (
    select customer_code, position_date, sum(market_value) as customer_total_market_value
    from position_with_customer
    group by 1, 2
)

select
    pwc.position_date,
    pwc.product_type,
    pwc.instrument_id,
    pwc.customer_code,
    pwc.market_value,
    cpt.customer_total_market_value,
    div0(pwc.market_value, nullif(cpt.customer_total_market_value, 0)) as pct_of_customer_portfolio,
    sum(pwc.market_value) over (partition by pwc.position_date, pwc.product_type, pwc.instrument_id)
        as firm_wide_market_value_in_instrument
from position_with_customer pwc
join customer_portfolio_total cpt
    on cpt.customer_code = pwc.customer_code and cpt.position_date = pwc.position_date
