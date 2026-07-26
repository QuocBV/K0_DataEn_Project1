-- Report 10: Dong tien Quy mo OEF - net subscription/redemption theo quy, theo NAV.
select
    t.trade_date,
    t.fund_id,
    f.fund_code,
    f.fund_name,
    nav.nav_price,
    sum(case when t.transaction_type = 'SUBSCRIBE' then t.amount else 0 end) as subscribe_amount,
    sum(case when t.transaction_type = 'REDEEM'    then t.amount else 0 end) as redeem_amount,
    sum(case when t.transaction_type = 'SUBSCRIBE' then t.amount
             when t.transaction_type = 'REDEEM'    then -t.amount
             else 0 end)                                                     as net_flow_amount,
    count(distinct t.customer_code)                                          as trading_customer_count
from {{ ref('stg_oef__oef_trade') }} t
join {{ ref('dim_fund') }} f on f.fund_id = t.fund_id
left join {{ ref('stg_oef__fund_nav_history') }} nav
    on nav.fund_id = t.fund_id and nav.nav_date = t.trade_date
group by 1, 2, 3, 4, 5
