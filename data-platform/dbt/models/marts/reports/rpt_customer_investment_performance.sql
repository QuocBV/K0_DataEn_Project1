-- Report 11: Hieu suat dau tu KH so voi benchmark VN-Index theo thang.
-- Simplification: return = (end_value - start_value) / start_value, not adjusted for intra-month
-- deposits/withdrawals (no cash-flow ledger modeled yet) - good enough for a directional
-- benchmark comparison, not for exact TWR/MWR performance attribution.
with customer_monthly_value as (
    select
        a.customer_code,
        year(f.balance_date)  as value_year,
        month(f.balance_date) as value_month,
        min_by(f.total_asset_value, f.balance_date) as start_value,
        max_by(f.total_asset_value, f.balance_date) as end_value
    from {{ ref('fact_account_balance_daily') }} f
    join {{ ref('dim_account') }} a
        on a.product_type = f.product_type and a.account_id = f.account_id
    group by 1, 2, 3
),

vnindex_monthly as (
    select
        year(price_date)  as value_year,
        month(price_date) as value_month,
        min_by(close_value, price_date) as start_index,
        max_by(close_value, price_date) as end_index
    from {{ ref('stg_common__market_index_price') }}
    where index_code = 'VNINDEX'
    group by 1, 2
)

select
    cmv.customer_code,
    c.customer_name,
    cmv.value_year,
    cmv.value_month,
    cmv.start_value,
    cmv.end_value,
    div0(cmv.end_value - cmv.start_value, nullif(cmv.start_value, 0)) as customer_return_pct,
    div0(vi.end_index - vi.start_index, nullif(vi.start_index, 0))    as vnindex_return_pct,
    div0(cmv.end_value - cmv.start_value, nullif(cmv.start_value, 0))
        - div0(vi.end_index - vi.start_index, nullif(vi.start_index, 0)) as excess_return_vs_vnindex
from customer_monthly_value cmv
join {{ ref('dim_customer') }} c on c.customer_code = cmv.customer_code
left join vnindex_monthly vi
    on vi.value_year = cmv.value_year and vi.value_month = cmv.value_month
