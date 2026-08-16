{{ config(materialized='table', schema='reporting') }}

with broker_kpi as (
    select broker_code, broker_name,
           sum(broker_commission_amount) as total_commission,
           rank() over (order by sum(broker_commission_amount) desc) as rank
    from {{ ref('rpt_broker_commission_revenue') }}
    group by 1,2
)
select
    k.broker_code, k.broker_name, k.total_commission, k.rank,
    ms.management_level, ms.commission_rate,
    k.total_commission * ms.commission_rate as management_commission_amount
from broker_kpi k
cross join {{ ref('dim_management_commission_schedule') }} ms
where ms.is_current
