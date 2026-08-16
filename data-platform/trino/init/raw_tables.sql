-- Create raw schemas + external tables on Trino (hive connector)
-- Matches Airbyte S3 layout: s3://de-project-commission/raw/SSI_Common/... etc.
-- Run inside trino: trino --execute @file.sql

CREATE SCHEMA IF NOT EXISTS raw."SSI_Common" WITH (location = 's3://de-project-commission/raw/SSI_Common');
CREATE SCHEMA IF NOT EXISTS raw."SSI_Equity" WITH (location = 's3://de-project-commission/raw/SSI_Equity');
CREATE SCHEMA IF NOT EXISTS raw."SSI_Derivatives" WITH (location = 's3://de-project-commission/raw/SSI_Derivatives');
CREATE SCHEMA IF NOT EXISTS raw."SSI_OEF" WITH (location = 's3://de-project-commission/raw/SSI_OEF');

-- ============ SSI_Common ============
CREATE TABLE IF NOT EXISTS raw."SSI_Common".account (
    account_id bigint, account_no varchar, customer_code varchar, broker_code varchar,
    product_type varchar, open_date timestamp(3), is_active boolean, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/account/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".branch (
    branch_id bigint, branch_code varchar, branch_name varchar, address varchar,
    director_employee_code varchar, is_active boolean, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/branch/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".broker (
    broker_code varchar, broker_name varchar, broker_type varchar, broker_subtype varchar,
    department_id bigint, employee_code varchar, id_number varchar, phone varchar,
    email varchar, start_date timestamp(3), end_date timestamp(3), is_active boolean,
    source_system varchar, source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/broker/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer (
    customer_code varchar, customer_name varchar, customer_type varchar, residency varchar,
    id_number varchar, phone varchar, email varchar, open_date timestamp(3), is_active boolean,
    source_system varchar, source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer_broker_history (
    history_id bigint, customer_code varchar, broker_code varchar, valid_from timestamp(3),
    valid_to timestamp(3), is_current boolean, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer_broker_history/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer_risk_profile (
    history_id bigint, customer_code varchar, investor_classification varchar, risk_level varchar,
    valid_from timestamp(3), valid_to timestamp(3), is_current boolean, source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer_risk_profile/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer_segment_history (
    history_id bigint, customer_code varchar, segment varchar, valid_from timestamp(3),
    valid_to timestamp(3), is_current boolean, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer_segment_history/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer_acquisition (
    customer_code varchar, acquisition_channel varchar, referral_broker_code varchar,
    acquisition_date timestamp(3), campaign_code varchar, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer_acquisition/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".fee_schedule (
    fee_schedule_id bigint, product_type varchar, broker_tier varchar, fee_rate decimal(38,8),
    commission_rate decimal(38,8), effective_from timestamp(3), effective_to timestamp(3),
    is_current boolean, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/fee_schedule/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".management_commission_schedule (
    schedule_id bigint, management_level varchar, commission_rate decimal(38,8),
    effective_from timestamp(3), effective_to timestamp(3), is_current boolean,
    source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/management_commission_schedule/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".market_index_price (
    price_date timestamp(3), index_code varchar, close_value decimal(38,8),
    change_percent decimal(38,8), volume bigint, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/market_index_price/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".trading_alert (
    alert_id bigint, alert_date timestamp(3), customer_code varchar, broker_code varchar,
    related_product_type varchar, related_source_system varchar, related_trade_id varchar,
    alert_type varchar, severity varchar, status varchar, description varchar,
    source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/trading_alert/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".customer_complaint (
    complaint_id bigint, customer_code varchar, broker_code varchar, complaint_date timestamp(3),
    channel varchar, category varchar, status varchar, resolution_date timestamp(3),
    description varchar, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/customer_complaint/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Common".employees (
    id_number varchar, employee_code varchar, full_name varchar, person_type varchar,
    branch_code varchar, branch_name varchar, department_code varchar, department_name varchar,
    position varchar, position_code varchar, position_level varchar, manager_employee_code varchar,
    start_date timestamp(3), end_date timestamp(3), status varchar,
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Common/employees/', format = 'PARQUET');

-- ============ SSI_Equity ============
CREATE TABLE IF NOT EXISTS raw."SSI_Equity".security (
    security_id bigint, symbol varchar, security_name varchar, exchange varchar, sector varchar,
    security_type varchar, listing_date timestamp(3), is_active boolean, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/security/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Equity".daily_price (
    price_date timestamp(3), security_id bigint, close_price decimal(38,8),
    reference_price decimal(38,8), ceiling_price decimal(38,8), floor_price decimal(38,8),
    volume bigint, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/daily_price/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Equity".equity_trade (
    trade_id bigint, trade_date timestamp(3), trade_datetime timestamp(3),
    source_trade_id varchar, account_no varchar, customer_code varchar, broker_code varchar,
    security_id bigint, market varchar, side varchar, order_type varchar, quantity bigint,
    price decimal(38,8), amount decimal(38,8), fee_amount decimal(38,8), tax_amount decimal(38,8),
    settlement_date timestamp(3), order_id varchar, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/equity_trade/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Equity".account_balance_daily (
    balance_date timestamp(3), account_no varchar, cash_balance decimal(38,8),
    portfolio_value decimal(38,8), total_asset_value decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/account_balance_daily/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Equity".position_daily (
    position_date timestamp(3), account_no varchar, security_id bigint, quantity bigint,
    avg_cost_price decimal(38,8), market_value decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/position_daily/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Equity".margin_loan_daily (
    loan_date timestamp(3), account_no varchar, margin_loan_balance decimal(38,8),
    margin_ratio decimal(38,8), maintenance_margin_ratio decimal(38,8), call_margin_flag boolean,
    source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Equity/margin_loan_daily/', format = 'PARQUET');

-- ============ SSI_Derivatives ============
CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".derivative_contract (
    contract_id bigint, contract_code varchar, underlying_symbol varchar, contract_type varchar,
    multiplier decimal(38,8), listing_date timestamp(3), maturity_date timestamp(3),
    is_active boolean, source_system varchar, source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/derivative_contract/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".daily_settlement_price (
    price_date timestamp(3), contract_id bigint, settlement_price decimal(38,8),
    open_interest bigint, volume bigint, source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/daily_settlement_price/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".derivative_trade (
    trade_id bigint, trade_date timestamp(3), trade_datetime timestamp(3),
    source_trade_id varchar, account_no varchar, customer_code varchar, broker_code varchar,
    contract_id bigint, position_side varchar, order_action varchar, quantity bigint,
    price decimal(38,8), amount decimal(38,8), margin_amount decimal(38,8), fee_amount decimal(38,8),
    settlement_date timestamp(3), order_id varchar, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/derivative_trade/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".account_balance_daily (
    balance_date timestamp(3), account_no varchar, cash_balance decimal(38,8),
    portfolio_value decimal(38,8), total_asset_value decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/account_balance_daily/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".position_daily (
    position_date timestamp(3), account_no varchar, contract_id bigint, position_side varchar,
    quantity bigint, avg_cost_price decimal(38,8), market_value decimal(38,8),
    source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/position_daily/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_Derivatives".margin_loan_daily (
    loan_date timestamp(3), account_no varchar, margin_loan_balance decimal(38,8),
    margin_ratio decimal(38,8), maintenance_margin_ratio decimal(38,8), call_margin_flag boolean,
    source_system varchar, ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_Derivatives/margin_loan_daily/', format = 'PARQUET');

-- ============ SSI_OEF ============
CREATE TABLE IF NOT EXISTS raw."SSI_OEF".fund (
    fund_id bigint, fund_code varchar, fund_name varchar, fund_type varchar,
    fund_manager varchar, inception_date timestamp(3), is_active boolean, source_system varchar,
    source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_OEF/fund/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_OEF".fund_nav_history (
    nav_date timestamp(3), fund_id bigint, nav_price decimal(38,8),
    total_net_asset decimal(38,8), outstanding_units decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_OEF/fund_nav_history/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_OEF".oef_trade (
    trade_id bigint, trade_date timestamp(3), trade_datetime timestamp(3),
    source_trade_id varchar, account_no varchar, customer_code varchar, broker_code varchar,
    fund_id bigint, transaction_type varchar, quantity_unit decimal(38,8), nav_price decimal(38,8),
    amount decimal(38,8), fee_amount decimal(38,8), settlement_date timestamp(3),
    order_id varchar, source_system varchar, source_updated_at timestamp(3), ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_OEF/oef_trade/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_OEF".account_balance_daily (
    balance_date timestamp(3), account_no varchar, cash_balance decimal(38,8),
    portfolio_value decimal(38,8), total_asset_value decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_OEF/account_balance_daily/', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS raw."SSI_OEF".position_daily (
    position_date timestamp(3), account_no varchar, fund_id bigint, quantity_unit decimal(38,8),
    avg_cost_nav decimal(38,8), market_value decimal(38,8), source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar, _airbyte_emitted_at timestamp(3), _airbyte_raw_id varchar, _airbyte_data json)
WITH (external_location = 's3://de-project-commission/raw/SSI_OEF/position_daily/', format = 'PARQUET');