-- Customer history view (SCD2 pass-through). dbt-trino does not support snapshot
-- strategy='check' + check_cols='all', so we expose current customer state here and
-- rely on bronze/silver sources for full SCD2 history (customer_broker_history,
-- customer_segment_history, customer_risk_profile) when point-in-time is needed.
select
    customer_code,
    customer_name,
    customer_type,
    residency,
    open_date,
    is_active,
    current_broker_code,
    current_segment,
    investor_classification,
    current_risk_level,
    acquisition_channel,
    acquisition_date,
    referral_broker_code,
    campaign_code
from {{ ref('dim_customer') }}
