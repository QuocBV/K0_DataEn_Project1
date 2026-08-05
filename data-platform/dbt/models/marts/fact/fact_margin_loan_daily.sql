{{ config(materialized='incremental', unique_key=['product_type', 'account_no', 'loan_date']) }}

-- Grain: one row per (product_type, account_no, loan_date). No OEF here - fund certificates are
-- not traded on margin (see Database/OEF/04_account_position.sql).
-- account_no is the global unified key (SSI_Common.raw.account); no per-DB account_id collisions.
select 'EQUITY' as product_type, account_no, loan_date, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag
from {{ source('silver', 'margin_loan_daily') }}
where _source_db = 'equity'

{% if is_incremental() %}
and loan_date > (select coalesce(max(loan_date), '1900-01-01') from {{ this }} where product_type = 'EQUITY')
{% endif %}

union all

select 'DERIVATIVES' as product_type, account_no, loan_date, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag
from {{ source('silver', 'margin_loan_daily') }}
where _source_db = 'derivatives'

{% if is_incremental() %}
and loan_date > (select coalesce(max(loan_date), '1900-01-01') from {{ this }} where product_type = 'DERIVATIVES')
{% endif %}