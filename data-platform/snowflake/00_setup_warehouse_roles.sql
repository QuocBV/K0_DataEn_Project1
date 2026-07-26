-- Run as ACCOUNTADMIN (or a role with CREATE WAREHOUSE/ROLE/USER privileges).
-- Sets up the compute warehouse and functional roles used by Airbyte (EL) and dbt (T).
-- Actual passwords/keys must come from vault/env, never hardcoded here.

CREATE WAREHOUSE IF NOT EXISTS WH_INGEST
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Used by Airbyte for EL (raw landing) syncs from the 4 SQL Server sources';

CREATE WAREHOUSE IF NOT EXISTS WH_TRANSFORM
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Used by dbt for staging/dim/fact/report transformations';

CREATE ROLE IF NOT EXISTS LOADER_ROLE;   -- used by the Airbyte destination connection
CREATE ROLE IF NOT EXISTS TRANSFORM_ROLE; -- used by dbt
CREATE ROLE IF NOT EXISTS REPORTING_ROLE; -- read-only, used by BI tools on top of marts.reports

GRANT USAGE ON WAREHOUSE WH_INGEST TO ROLE LOADER_ROLE;
GRANT USAGE ON WAREHOUSE WH_TRANSFORM TO ROLE TRANSFORM_ROLE;
GRANT USAGE ON WAREHOUSE WH_TRANSFORM TO ROLE REPORTING_ROLE;

-- Attach roles to the service users configured in Airbyte/dbt (create the users separately via
-- vault-managed credentials, then run e.g. GRANT ROLE LOADER_ROLE TO USER AIRBYTE_SVC_USER;).
