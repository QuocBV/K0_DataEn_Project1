-- dbt snapshot for customer profile SCD Type 2.
-- Captures the full customer row each time dim_customer is rebuilt, so dim_customer_history
-- can track who had which broker/segment/risk assignment at any point in time.
-- Uses 'check' strategy (compares all columns) instead of 'timestamp' because the source
-- (dim_customer) does not have a reliable last-modified column - it is rebuilt daily.
{{ config(
    target_schema='snapshots',
    unique_key='customer_code',
    strategy='check',
    check_cols='all'
) }}

select * from {{ ref('dim_customer') }}