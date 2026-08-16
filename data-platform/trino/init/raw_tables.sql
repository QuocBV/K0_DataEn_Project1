-- Create raw schemas + external tables on Trino (hive connector)
-- Run inside trino: trino --execute @file.sql


-- SSI_Common namespace: common
-- SSI_Equity namespace: equity
-- SSI_Derivatives namespace: derivatives
-- SSI_OEF namespace: oef
CREATE SCHEMA IF NOT EXISTS raw.common WITH (location = 's3://ssi-data/raw/COMMON');
CREATE SCHEMA IF NOT EXISTS raw.derivatives WITH (location = 's3://ssi-data/raw/DERIVATIVES');
CREATE SCHEMA IF NOT EXISTS raw.equity WITH (location = 's3://ssi-data/raw/EQUITY');
CREATE SCHEMA IF NOT EXISTS raw.oef WITH (location = 's3://ssi-data/raw/OEF');

-- account from common
CREATE TABLE IF NOT EXISTS raw.common_account (
    account_id bigint,
    account_no varchar,
    customer_code varchar,
    broker_code varchar,
    product_type varchar,
    open_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/account/', format = 'PARQUET');

-- branch from common
CREATE TABLE IF NOT EXISTS raw.common_branch (
    branch_id bigint,
    branch_code varchar,
    branch_name varchar,
    address varchar,
    director_employee_code varchar,
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/branch/', format = 'PARQUET');

-- broker from common
CREATE TABLE IF NOT EXISTS raw.common_broker (
    broker_code varchar,
    broker_name varchar,
    broker_type varchar,
    broker_subtype varchar,
    department_id bigint,
    employee_code varchar,
    id_number varchar,
    phone varchar,
    email varchar,
    start_date timestamp(3),
    end_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/broker/', format = 'PARQUET');

-- customer from common
CREATE TABLE IF NOT EXISTS raw.common_customer (
    customer_code varchar,
    customer_name varchar,
    customer_type varchar,
    residency varchar,
    id_number varchar,
    phone varchar,
    email varchar,
    open_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer/', format = 'PARQUET');

-- customer_acquisition from common
CREATE TABLE IF NOT EXISTS raw.common_customer_acquisition (
    customer_code varchar,
    acquisition_channel varchar,
    referral_broker_code varchar,
    acquisition_date timestamp(3),
    campaign_code varchar,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer_acquisition/', format = 'PARQUET');

-- customer_broker_history from common
CREATE TABLE IF NOT EXISTS raw.common_customer_broker_history (
    history_id bigint,
    customer_code varchar,
    broker_code varchar,
    valid_from timestamp(3),
    valid_to timestamp(3),
    is_current boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer_broker_history/', format = 'PARQUET');

-- customer_complaint from common
CREATE TABLE IF NOT EXISTS raw.common_customer_complaint (
    complaint_id bigint,
    customer_code varchar,
    broker_code varchar,
    complaint_date timestamp(3),
    channel varchar,
    category varchar,
    status varchar,
    resolution_date timestamp(3),
    description varchar,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer_complaint/', format = 'PARQUET');

-- customer_risk_profile from common
CREATE TABLE IF NOT EXISTS raw.common_customer_risk_profile (
    history_id bigint,
    customer_code varchar,
    investor_classification varchar,
    risk_level varchar,
    valid_from timestamp(3),
    valid_to timestamp(3),
    is_current boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer_risk_profile/', format = 'PARQUET');

-- customer_segment_history from common
CREATE TABLE IF NOT EXISTS raw.common_customer_segment_history (
    history_id bigint,
    customer_code varchar,
    segment varchar,
    valid_from timestamp(3),
    valid_to timestamp(3),
    is_current boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/customer_segment_history/', format = 'PARQUET');

-- department from common
CREATE TABLE IF NOT EXISTS raw.common_department (
    department_id bigint,
    department_code varchar,
    department_name varchar,
    branch_id bigint,
    department_type varchar,
    head_employee_code varchar,
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/department/', format = 'PARQUET');

-- fee_schedule from common
CREATE TABLE IF NOT EXISTS raw.common_fee_schedule (
    fee_schedule_id bigint,
    product_type varchar,
    broker_tier varchar,
    fee_rate decimal(38,8),
    commission_rate decimal(38,8),
    effective_from timestamp(3),
    effective_to timestamp(3),
    is_current boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/fee_schedule/', format = 'PARQUET');

-- management_commission_schedule from common
CREATE TABLE IF NOT EXISTS raw.common_management_commission_schedule (
    schedule_id bigint,
    management_level varchar,
    commission_rate decimal(38,8),
    effective_from timestamp(3),
    effective_to timestamp(3),
    is_current boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/management_commission_schedule/', format = 'PARQUET');

-- market_index_price from common
CREATE TABLE IF NOT EXISTS raw.common_market_index_price (
    price_date timestamp(3),
    index_code varchar,
    close_value decimal(38,8),
    change_percent decimal(38,8),
    volume bigint,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/market_index_price/', format = 'PARQUET');

-- trading_alert from common
CREATE TABLE IF NOT EXISTS raw.common_trading_alert (
    alert_id bigint,
    alert_date timestamp(3),
    customer_code varchar,
    broker_code varchar,
    related_product_type varchar,
    related_source_system varchar,
    related_trade_id varchar,
    alert_type varchar,
    severity varchar,
    status varchar,
    description varchar,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/COMMON/trading_alert/', format = 'PARQUET');

-- account_balance_daily from equity
CREATE TABLE IF NOT EXISTS raw.equity_account_balance_daily (
    balance_date timestamp(3),
    account_no varchar,
    cash_balance decimal(38,8),
    portfolio_value decimal(38,8),
    total_asset_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- account_balance_daily from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_account_balance_daily (
    balance_date timestamp(3),
    account_no varchar,
    cash_balance decimal(38,8),
    portfolio_value decimal(38,8),
    total_asset_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- account_balance_daily from oef
CREATE TABLE IF NOT EXISTS raw.oef_account_balance_daily (
    balance_date timestamp(3),
    account_no varchar,
    cash_balance decimal(38,8),
    portfolio_value decimal(38,8),
    total_asset_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- daily_price from equity
CREATE TABLE IF NOT EXISTS raw.equity_daily_price (
    price_date timestamp(3),
    security_id bigint,
    close_price decimal(38,8),
    reference_price decimal(38,8),
    ceiling_price decimal(38,8),
    floor_price decimal(38,8),
    volume bigint,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/EQUITY/daily_price/', format = 'PARQUET');

-- equity_trade from equity
CREATE TABLE IF NOT EXISTS raw.equity_equity_trade (
    trade_id bigint,
    trade_date timestamp(3),
    trade_datetime timestamp(3),
    source_trade_id varchar,
    account_no varchar,
    customer_code varchar,
    broker_code varchar,
    security_id bigint,
    market varchar,
    side varchar,
    order_type varchar,
    quantity bigint,
    price decimal(38,8),
    amount decimal(38,8),
    fee_amount decimal(38,8),
    tax_amount decimal(38,8),
    settlement_date timestamp(3),
    order_id varchar,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/EQUITY/equity_trade/', format = 'PARQUET');

-- margin_loan_daily from equity
CREATE TABLE IF NOT EXISTS raw.equity_margin_loan_daily (
    loan_date timestamp(3),
    account_no varchar,
    margin_loan_balance decimal(38,8),
    margin_ratio decimal(38,8),
    maintenance_margin_ratio decimal(38,8),
    call_margin_flag boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- margin_loan_daily from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_margin_loan_daily (
    loan_date timestamp(3),
    account_no varchar,
    margin_loan_balance decimal(38,8),
    margin_ratio decimal(38,8),
    maintenance_margin_ratio decimal(38,8),
    call_margin_flag boolean,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- position_daily from equity
CREATE TABLE IF NOT EXISTS raw.equity_position_daily (
    position_date timestamp(3),
    account_no varchar,
    security_id bigint,
    quantity bigint,
    avg_cost_price decimal(38,8),
    market_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- position_daily from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_position_daily (
    position_date timestamp(3),
    account_no varchar,
    contract_id bigint,
    position_side varchar,
    quantity bigint,
    avg_cost_price decimal(38,8),
    market_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- position_daily from oef
CREATE TABLE IF NOT EXISTS raw.oef_position_daily (
    position_date timestamp(3),
    account_no varchar,
    fund_id bigint,
    quantity_unit bigint,
    avg_cost_nav decimal(38,8),
    market_value decimal(38,8),
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data row)

-- security from equity
CREATE TABLE IF NOT EXISTS raw.equity_security (
    security_id bigint,
    symbol varchar,
    security_name varchar,
    exchange varchar,
    sector varchar,
    security_type varchar,
    listing_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/EQUITY/security/', format = 'PARQUET');

-- daily_settlement_price from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_daily_settlement_price (
    price_date timestamp(3),
    contract_id bigint,
    settlement_price decimal(38,8),
    open_interest bigint,
    volume bigint,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/DERIVATIVES/daily_settlement_price/', format = 'PARQUET');

-- derivative_contract from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_derivative_contract (
    contract_id bigint,
    contract_code varchar,
    underlying_symbol varchar,
    contract_type varchar,
    multiplier decimal(38,8),
    listing_date timestamp(3),
    maturity_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/DERIVATIVES/derivative_contract/', format = 'PARQUET');

-- derivative_trade from derivatives
CREATE TABLE IF NOT EXISTS raw.derivatives_derivative_trade (
    trade_id bigint,
    trade_date timestamp(3),
    trade_datetime timestamp(3),
    source_trade_id varchar,
    account_no varchar,
    customer_code varchar,
    broker_code varchar,
    contract_id bigint,
    position_side varchar,
    order_action varchar,
    quantity bigint,
    price decimal(38,8),
    amount decimal(38,8),
    margin_amount decimal(38,8),
    fee_amount decimal(38,8),
    settlement_date timestamp(3),
    order_id varchar,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/DERIVATIVES/derivative_trade/', format = 'PARQUET');

-- fund from oef
CREATE TABLE IF NOT EXISTS raw.oef_fund (
    fund_id bigint,
    fund_code varchar,
    fund_name varchar,
    fund_type varchar,
    fund_manager varchar,
    inception_date timestamp(3),
    is_active boolean,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/OEF/fund/', format = 'PARQUET');

-- fund_nav_history from oef
CREATE TABLE IF NOT EXISTS raw.oef_fund_nav_history (
    nav_date timestamp(3),
    fund_id bigint,
    nav_price decimal(38,8),
    total_net_asset varchar,
    outstanding_units varchar,
    source_system varchar,
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/OEF/fund_nav_history/', format = 'PARQUET');

-- oef_trade from oef
CREATE TABLE IF NOT EXISTS raw.oef_oef_trade (
    trade_id bigint,
    trade_date timestamp(3),
    trade_datetime timestamp(3),
    source_trade_id varchar,
    account_no varchar,
    customer_code varchar,
    broker_code varchar,
    fund_id bigint,
    transaction_type varchar,
    quantity_unit bigint,
    nav_price decimal(38,8),
    amount decimal(38,8),
    fee_amount decimal(38,8),
    settlement_date timestamp(3),
    order_id varchar,
    source_system varchar,
    source_updated_at timestamp(3),
    ingested_at timestamp(3),
    _airbyte_ab_id varchar,
    _airbyte_emitted_at timestamp(3),
    _airbyte_raw_id varchar,
    _airbyte_data json)
WITH (external_location = 's3://ssi-data/raw/OEF/oef_trade/', format = 'PARQUET');
