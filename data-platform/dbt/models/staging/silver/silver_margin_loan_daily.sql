{{ config(materialized='table') }}

-- Silver: margin_loan_daily bronze -> clean/dedup -> Iceberg silver
select
    loan_date,
    account_no,
    margin_loan_balance,
    margin_ratio,
    maintenance_margin_ratio,
    call_margin_flag,
    source_system,
    ingested_at,
    _source_db
from {{ ref('bronze_margin_loan_daily') }}
