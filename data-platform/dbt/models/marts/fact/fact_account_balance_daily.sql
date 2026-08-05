{{ config(materialized='incremental', unique_key=['product_type', 'account_no', 'balance_date']) }}

-- Grain: one row per (product_type, account_no, balance_date). Snapshot tables still live in the
-- 3 product DBs (equity / derivatives / oef), each keyed by the GLOBAL account_no (see
-- 04_account_position.sql). account_no is unique across products, no per-DB account_id collisions.
select 'EQUITY' as product_type, account_no, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ source('silver', 'account_balance_daily') }}
where _source_db = 'equity'

{% if is_incremental() %}
and balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'EQUITY')
{% endif %}

union all

select 'DERIVATIVES' as product_type, account_no, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ source('silver', 'account_balance_daily') }}
where _source_db = 'derivatives'

{% if is_incremental() %}
and balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'DERIVATIVES')
{% endif %}

union all

select 'OEF' as product_type, account_no, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ source('silver', 'account_balance_daily') }}
where _source_db = 'oef'

{% if is_incremental() %}
and balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'OEF')
{% endif %}