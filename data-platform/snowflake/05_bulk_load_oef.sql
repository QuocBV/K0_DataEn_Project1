-- Bulk file-based load path for SSI_OEF's heavy tables. Same VARIANT-landing design as
-- 03_bulk_load_equity.sql (read that file's header for the full rationale). No margin_loan_daily
-- here - OEF certificates are not traded on margin.
USE ROLE TRANSFORM_ROLE;
USE WAREHOUSE WH_INGEST;

CREATE FILE FORMAT IF NOT EXISTS RAW.OEF.FF_PARQUET
    TYPE = PARQUET
    COMPRESSION = SNAPPY;

CREATE STAGE IF NOT EXISTS RAW.OEF.STG_LANDING
    STORAGE_INTEGRATION = SSI_LANDING_INTEGRATION
    URL = 'azure://ssidl.blob.core.windows.net/landing/oef'
    FILE_FORMAT = RAW.OEF.FF_PARQUET;

CALL RAW.UTIL.CREATE_VARIANT_LANDING('OEF', 'OEF_TRADE',            'oef_trade');
CALL RAW.UTIL.CREATE_VARIANT_LANDING('OEF', 'ACCOUNT_BALANCE_DAILY', 'account_balance_daily');
CALL RAW.UTIL.CREATE_VARIANT_LANDING('OEF', 'POSITION_DAILY',        'position_daily');
