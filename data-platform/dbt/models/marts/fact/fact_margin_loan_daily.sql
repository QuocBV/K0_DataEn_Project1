{{ config(materialized='incremental', unique_key=['product_type', 'account_id', 'loan_date']) }}

-- Grain: one row per (product_type, account_id, loan_date). No OEF here - fund certificates are
-- not traded on margin (see Database/OEF/04_account_position.sql).
select 'EQUITY' as product_type, account_id, loan_date, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag
from {{ ref('stg_equity__margin_loan_daily') }}

{% if is_incremental() %}
where loan_date > (select coalesce(max(loan_date), '1900-01-01') from {{ this }} where product_type = 'EQUITY')
{% endif %}

union all

select 'DERIVATIVES' as product_type, account_id, loan_date, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag
from {{ ref('stg_derivatives__margin_loan_daily') }}

{% if is_incremental() %}
where loan_date > (select coalesce(max(loan_date), '1900-01-01') from {{ this }} where product_type = 'DERIVATIVES')
{% endif %}
