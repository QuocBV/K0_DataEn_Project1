{{ config(materialized='table') }}

-- Bronze: position_daily raw Parquet -> Iceberg bronze
select position_date, account_no, security_id, quantity, avg_cost_price, market_value, source_system, ingested_at, 'equity' as _source_db
from {{ source('raw_equity', 'position_daily') }}
union all
select position_date, account_no, contract_id, position_side, quantity, avg_cost_price, market_value, source_system, ingested_at, 'derivatives' as _source_db
from {{ source('raw_derivatives', 'position_daily') }}
union all
select position_date, account_no, fund_id, quantity_unit, avg_cost_nav, market_value, source_system, ingested_at, 'oef' as _source_db
from {{ source('raw_oef', 'position_daily') }}
