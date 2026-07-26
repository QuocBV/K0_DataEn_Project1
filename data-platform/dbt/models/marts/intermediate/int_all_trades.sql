{{ config(materialized='view') }}

-- Common trade grain shared by all 3 product lines, used by every report that aggregates
-- commission/revenue/activity across products (rpt_broker_commission_revenue,
-- rpt_department_branch_ranking, rpt_broker_performance, rpt_trading_activity_summary,
-- rpt_customer_cross_sell, rpt_management_override_commission). Defined once here instead of
-- re-writing the same 3-way UNION ALL in every report model.
select product_type, trade_id, trade_date, customer_code, broker_code, account_no, amount, fee_amount
from {{ ref('fact_equity_trade') }}

union all

select product_type, trade_id, trade_date, customer_code, broker_code, account_no, amount, fee_amount
from {{ ref('fact_derivative_trade') }}

union all

select product_type, trade_id, trade_date, customer_code, broker_code, account_no, amount, fee_amount
from {{ ref('fact_oef_trade') }}
