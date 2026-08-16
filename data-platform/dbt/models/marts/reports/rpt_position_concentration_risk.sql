{{ config(materialized='table', schema='reporting') }}

with acct_portfolio as (
    select account_no, product_type, sum(market_value) as portfolio_value
    from {{ ref('fact_position_daily') }}
    group by 1,2
)
select
    p.product_type, p.account_no, a.customer_code,
    p.instrument_id, s.symbol, s.sector,
    p.market_value, ap.portfolio_value,
    p.market_value / ap.portfolio_value as concentration_pct,
    case when p.market_value / ap.portfolio_value > 0.3 then 'HIGH' else 'NORMAL' end as risk_level,
    p.position_date
from {{ ref('fact_position_daily') }} p
join acct_portfolio ap on ap.account_no = p.account_no and ap.product_type = p.product_type
left join {{ ref('dim_security') }} s on s.security_id = p.instrument_id and p.product_type = 'EQUITY'
left join {{ ref('dim_derivative_contract') }} dc on dc.contract_id = p.instrument_id and p.product_type = 'DERIVATIVES'
left join {{ ref('dim_fund') }} f on f.fund_id = p.instrument_id and p.product_type = 'OEF'
left join {{ ref('dim_account') }} a on a.account_no = p.account_no
