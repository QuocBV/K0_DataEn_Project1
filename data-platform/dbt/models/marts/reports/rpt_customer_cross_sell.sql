-- Report 12: Cross-sell - khach hang dang su dung bao nhieu trong 3 mang san pham
-- (co so / phai sinh / OEF), dung de xac dinh co hoi ban cheo.
with product_usage as (
    select
        customer_code,
        max(case when product_type = 'EQUITY' then 1 else 0 end)      as uses_equity,
        max(case when product_type = 'DERIVATIVES' then 1 else 0 end) as uses_derivatives,
        max(case when product_type = 'OEF' then 1 else 0 end)         as uses_oef
    from {{ ref('int_all_trades') }}
    group by customer_code
)

select
    c.customer_code,
    c.customer_name,
    c.current_segment,
    c.current_broker_code,
    b.broker_name,
    coalesce(pu.uses_equity, 0)      as uses_equity,
    coalesce(pu.uses_derivatives, 0) as uses_derivatives,
    coalesce(pu.uses_oef, 0)         as uses_oef,
    coalesce(pu.uses_equity, 0) + coalesce(pu.uses_derivatives, 0) + coalesce(pu.uses_oef, 0)
        as product_count,
    case
        when coalesce(pu.uses_equity, 0) + coalesce(pu.uses_derivatives, 0) + coalesce(pu.uses_oef, 0) <= 1
        then true else false
    end as is_cross_sell_opportunity
from {{ ref('dim_customer') }} c
left join product_usage pu on pu.customer_code = c.customer_code
left join {{ ref('dim_broker') }} b on b.broker_code = c.current_broker_code
where c.is_active
