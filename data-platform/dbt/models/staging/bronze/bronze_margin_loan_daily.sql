{{ config(materialized='table') }}

-- Bronze: margin_loan_daily raw Parquet -> Iceberg bronze
select loan_date, account_no, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag, source_system, ingested_at, 'equity' as _source_db
from {{ source('raw_equity', 'margin_loan_daily') }}
union all
select loan_date, account_no, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag, source_system, ingested_at, 'derivatives' as _source_db
from {{ source('raw_derivatives', 'margin_loan_daily') }}
