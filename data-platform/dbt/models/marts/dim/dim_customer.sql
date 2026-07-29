-- Customer 360 "as of now" dimension: base attributes (Type 1) plus the CURRENT broker/segment/
-- risk profile. Reports needing the historical broker-of-record as of a past date should join
-- dim_customer_broker_history instead (e.g. AUM-by-broker-over-time) - this model is for reports
-- that only need "who owns this customer today" (acquisition funnel, dormant/churn, cross-sell).
with current_broker as (
    select customer_code, broker_code
    from {{ ref('dim_customer_broker_history') }}
    where is_current
),

current_segment as (
    select customer_code, segment
    from {{ source('silver', 'customer_segment_history') }}
    where is_current
),

current_risk as (
    select customer_code, investor_classification, risk_level
    from {{ source('silver', 'customer_risk_profile') }}
    where is_current
)

select
    c.customer_code,
    c.customer_name,
    c.customer_type,
    c.residency,
    c.open_date,
    c.is_active,
    cb.broker_code           as current_broker_code,
    cs.segment              as current_segment,
    cr.investor_classification,
    cr.risk_level            as current_risk_level,
    ca.acquisition_channel,
    ca.acquisition_date,
    ca.referral_broker_code,
    ca.campaign_code
from {{ source('silver', 'customer') }} c
left join current_broker cb on cb.customer_code = c.customer_code
left join current_segment cs on cs.customer_code = c.customer_code
left join current_risk cr on cr.customer_code = c.customer_code
left join {{ source('silver', 'customer_acquisition') }} ca on ca.customer_code = c.customer_code
