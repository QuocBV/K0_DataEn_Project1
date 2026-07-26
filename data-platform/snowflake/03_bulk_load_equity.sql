-- Bulk file-based load path for SSI_Equity's heavy tables (equity_trade, account_balance_daily,
-- position_daily, margin_loan_daily). These bypass Airbyte JDBC sync entirely - see
-- scripts/export_partition_to_parquet.py for why, and airbyte/connections/mssql_equity_to_snowflake.yaml
-- for what Airbyte still handles (the small dimension tables only).
--
-- Each table lands as raw VARIANT (see 02_variant_landing_util.sql) under its own stage subfolder
-- (@RAW.EQUITY.STG_LANDING/<table>/dt=<date>/*.parquet), matching the SQL Server monthly
-- partitioning already in place. Typing/flattening into typed columns happens in the dbt staging
-- layer (dbt/models/staging/equity/), not here.
USE ROLE TRANSFORM_ROLE;
USE WAREHOUSE WH_INGEST;

CREATE FILE FORMAT IF NOT EXISTS RAW.EQUITY.FF_PARQUET
    TYPE = PARQUET
    COMPRESSION = SNAPPY;

-- Storage integration must be created once by ACCOUNTADMIN (STORAGE INTEGRATION ...) pointing at
-- the landing container; referenced here by name only, no credentials in this file.
CREATE STAGE IF NOT EXISTS RAW.EQUITY.STG_LANDING
    STORAGE_INTEGRATION = SSI_LANDING_INTEGRATION
    URL = 'azure://ssidl.blob.core.windows.net/landing/equity'
    FILE_FORMAT = RAW.EQUITY.FF_PARQUET;

CALL RAW.UTIL.CREATE_VARIANT_LANDING('EQUITY', 'EQUITY_TRADE',         'equity_trade');
CALL RAW.UTIL.CREATE_VARIANT_LANDING('EQUITY', 'ACCOUNT_BALANCE_DAILY', 'account_balance_daily');
CALL RAW.UTIL.CREATE_VARIANT_LANDING('EQUITY', 'POSITION_DAILY',        'position_daily');
CALL RAW.UTIL.CREATE_VARIANT_LANDING('EQUITY', 'MARGIN_LOAN_DAILY',     'margin_loan_daily');

-- Manual/backfill load (used by the Airflow backfill task, or historical reprocessing):
-- COPY INTO RAW.EQUITY.EQUITY_TRADE_RAW (raw_data, _file_name)
--     FROM (SELECT $1, METADATA$FILENAME FROM @RAW.EQUITY.STG_LANDING/equity_trade/dt=2026-07-17/)
--     FILE_FORMAT = (FORMAT_NAME = RAW.EQUITY.FF_PARQUET) ON_ERROR = 'ABORT_STATEMENT';
-- Re-running for the same dt= prefix is safe: Snowflake skips files it already loaded (tracked by
-- file name + checksum for 64 days), so retries never duplicate rows.
