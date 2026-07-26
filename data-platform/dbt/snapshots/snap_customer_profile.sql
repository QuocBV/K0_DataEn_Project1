{#- SCD Type 2 "history" table for the consolidated customer profile, paired with dim_customer as
    the "current/main" table (2-table pattern: dim_customer = latest state only,
    dim_customer_history = every state the customer profile has ever been in, with valid_from/
    valid_to). dim_customer already joins 3 separate source SCD2 tables (broker assignment, risk
    profile, segment) to compute "current broker/segment/risk as of now" - this snapshot captures
    that COMBINED profile's own change history, so a report asking "what was this customer's full
    profile on 2027-03-15" is a single point-in-time lookup instead of 3 separate joins against the
    raw history tables.
    dbt's snapshot mechanism runs each time `dbt snapshot` executes (scheduled right after
    dim_customer rebuilds in dag_dbt_transform.py) and diffs the current dim_customer row against
    the last captured version per customer_code, using the `check` strategy: any check_cols
    difference closes the old row's dbt_valid_to and opens a new row - no destructive UPDATE ever
    happens to dim_customer_history, it is strictly append/close, so historical joins are stable
    even if dim_customer itself is fully rebuilt (table materialization) on every run. #}
{% snapshot snap_customer_profile %}

{{
    config(
        target_schema='MARTS',
        unique_key='customer_code',
        strategy='check',
        check_cols=['current_broker_code', 'current_segment', 'current_risk_level', 'investor_classification', 'is_active'],
    )
}}

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

{% endsnapshot %}
