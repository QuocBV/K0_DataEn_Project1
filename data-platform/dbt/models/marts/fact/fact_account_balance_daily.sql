{{ config(materialized='incremental', unique_key=['product_type', 'account_id', 'balance_date']) }}

-- Grain: one row per (product_type, account_id, balance_date). Always join on the full composite
-- key - account_id alone is not unique across product DBs (see dim_account.sql).
select 'EQUITY' as product_type, account_id, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ ref('stg_equity__account_balance_daily') }}

{% if is_incremental() %}
where balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'EQUITY')
{% endif %}

union all

select 'DERIVATIVES' as product_type, account_id, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ ref('stg_derivatives__account_balance_daily') }}

{% if is_incremental() %}
where balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'DERIVATIVES')
{% endif %}

union all

select 'OEF' as product_type, account_id, balance_date, cash_balance, portfolio_value, total_asset_value
from {{ ref('stg_oef__account_balance_daily') }}

{% if is_incremental() %}
where balance_date > (select coalesce(max(balance_date), '1900-01-01') from {{ this }} where product_type = 'OEF')
{% endif %}
