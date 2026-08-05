{{ config(materialized='incremental', unique_key=['product_type', 'account_no', 'instrument_id', 'position_date']) }}

-- Grain: one row per (product_type, account_no, instrument_id, position_date). instrument_id
-- means security_id for EQUITY, contract_id for DERIVATIVES, fund_id for OEF - join to
-- dim_security / dim_derivative_contract / dim_fund respectively based on product_type.
-- account_no is the global unified key (SSI_Common.raw.account); no per-DB account_id collisions.
select
    'EQUITY' as product_type, account_no, security_id as instrument_id, position_date,
    quantity, avg_cost_price as avg_cost, market_value
from {{ source('silver', 'position_daily') }}
where _source_db = 'equity'

{% if is_incremental() %}
and position_date > (select coalesce(max(position_date), '1900-01-01') from {{ this }} where product_type = 'EQUITY')
{% endif %}

union all

select
    'DERIVATIVES' as product_type, account_no, contract_id as instrument_id, position_date,
    quantity, avg_cost_price as avg_cost, market_value
from {{ source('silver', 'position_daily') }}
where _source_db = 'derivatives'

{% if is_incremental() %}
and position_date > (select coalesce(max(position_date), '1900-01-01') from {{ this }} where product_type = 'DERIVATIVES')
{% endif %}

union all

select
    'OEF' as product_type, account_no, fund_id as instrument_id, position_date,
    quantity_unit as quantity, avg_cost_nav as avg_cost, market_value
from {{ source('silver', 'position_daily') }}
where _source_db = 'oef'

{% if is_incremental() %}
and position_date > (select coalesce(max(position_date), '1900-01-01') from {{ this }} where product_type = 'OEF')
{% endif %}