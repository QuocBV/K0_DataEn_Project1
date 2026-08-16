{{ config(materialized='table', schema='reporting') }}

with eq as (select distinct customer_code from {{ ref('fact_equity_trade') }}),
de as (select distinct customer_code from {{ ref('fact_derivative_trade') }}),
oe as (select distinct customer_code from {{ ref('fact_oef_trade') }})
select
    c.customer_code, c.customer_name,
    case when e.customer_code is not null then 1 else 0 end as has_equity,
    case when d.customer_code is not null then 1 else 0 end as has_derivatives,
    case when o.customer_code is not null then 1 else 0 end as has_oef,
    case when e.customer_code is not null then 1 else 0 end
      + case when d.customer_code is not null then 1 else 0 end
      + case when o.customer_code is not null then 1 else 0 end as product_count
from {{ ref('dim_customer') }} c
left join eq e on e.customer_code = c.customer_code
left join de d on d.customer_code = c.customer_code
left join oe o on o.customer_code = c.customer_code
