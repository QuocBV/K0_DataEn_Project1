{{ config(materialized='table') }}

-- Bronze: account_balance_daily raw Parquet -> Iceberg bronze
select balance_date, account_no, cash_balance, portfolio_value, total_asset_value, source_system, ingested_at, 'equity' as _source_db
from {{ source('raw_equity', 'account_balance_daily') }}
union all
select balance_date, account_no, cash_balance, portfolio_value, total_asset_value, source_system, ingested_at, 'derivatives' as _source_db
from {{ source('raw_derivatives', 'account_balance_daily') }}
union all
select balance_date, account_no, cash_balance, portfolio_value, total_asset_value, source_system, ingested_at, 'oef' as _source_db
from {{ source('raw_oef', 'account_balance_daily') }}
