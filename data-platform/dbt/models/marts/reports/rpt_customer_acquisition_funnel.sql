-- Report 6: Khach hang moi & funnel theo kenh/CTV gioi thieu - so KH moi va ty le KH da phat sinh
-- giao dich that su (chuyen doi tu mo TK sang active trading).
with first_trade as (
    select customer_code, min(trade_date) as first_trade_date
    from {{ ref('int_all_trades') }}
    group by customer_code
)

select
    year(ca.acquisition_date)  as acquisition_year,
    month(ca.acquisition_date) as acquisition_month,
    ca.acquisition_channel,
    ca.campaign_code,
    ca.referral_broker_code,
    b.broker_name              as referral_broker_name,
    count(distinct ca.customer_code) as new_customer_count,
    count(distinct ft.customer_code) as converted_to_trading_count,
    div0(count(distinct ft.customer_code), nullif(count(distinct ca.customer_code), 0)) as conversion_rate
from {{ ref('stg_common__customer_acquisition') }} ca
left join {{ ref('dim_broker') }} b on b.broker_code = ca.referral_broker_code
left join first_trade ft on ft.customer_code = ca.customer_code
group by 1, 2, 3, 4, 5, 6
