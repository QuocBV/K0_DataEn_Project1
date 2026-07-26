-- "History" half of the customer SCD Type 2 pair (see snapshots/snap_customer_profile.sql for the
-- capture mechanism). dim_customer is the "main" table (current state only); this is the full
-- history, renamed to the same valid_from/valid_to/is_current convention used by
-- dim_customer_broker_history elsewhere in this project instead of dbt's raw dbt_valid_from/
-- dbt_valid_to/dbt_scd_id columns.
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
    campaign_code,
    dbt_valid_from as valid_from,
    dbt_valid_to   as valid_to,
    dbt_valid_to is null as is_current
from {{ ref('snap_customer_profile') }}
