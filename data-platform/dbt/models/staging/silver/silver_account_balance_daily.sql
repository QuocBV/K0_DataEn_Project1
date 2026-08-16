{{ config(materialized='table') }}

-- Silver: account_balance_daily bronze -> clean/dedup -> Iceberg silver
select
    balance_date,
    account_no,
    cash_balance,
    portfolio_value,
    total_asset_value,
    source_system,
    ingested_at,
    _source_db
from {{ ref('bronze_account_balance_daily') }}
