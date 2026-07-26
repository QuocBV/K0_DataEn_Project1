-- Metadata-driven landing helper: every heavy table (equity_trade, account_balance_daily,
-- position_daily, margin_loan_daily, ...) lands the same way - one VARIANT column holding the row
-- as-is, plus lineage columns. Loading raw and untyped (instead of mapping to typed columns at
-- COPY INTO time, as an earlier draft of this file did) means a source column being added/renamed/
-- reordered upstream cannot break the load; typing and flattening happens once, in the dbt staging
-- layer, where it's version-controlled and testable.
--
-- Writing 11 nearly-identical CREATE TABLE + CREATE PIPE blocks by hand (equity/derivatives/oef x
-- ~4 heavy tables each) is exactly the kind of copy-paste surface that drifts out of sync over
-- time - one procedure, called once per table, keeps them all structurally identical by
-- construction. See 03_bulk_load_equity.sql / 04_bulk_load_derivatives.sql / 05_bulk_load_oef.sql
-- for the CALL list.
USE ROLE TRANSFORM_ROLE;

CREATE SCHEMA IF NOT EXISTS RAW.UTIL;

CREATE OR REPLACE PROCEDURE RAW.UTIL.CREATE_VARIANT_LANDING(
    P_SCHEMA           STRING,  -- e.g. 'EQUITY'
    P_TABLE             STRING,  -- e.g. 'EQUITY_TRADE' -> lands in RAW.<schema>.<table>_RAW
    P_STAGE_SUBFOLDER   STRING   -- subfolder under RAW.<schema>.STG_LANDING, e.g. 'equity_trade'
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    full_table STRING DEFAULT 'RAW.' || P_SCHEMA || '.' || P_TABLE || '_RAW';
    pipe_name  STRING DEFAULT 'RAW.' || P_SCHEMA || '.PIPE_' || P_TABLE;
    stage_ref  STRING DEFAULT '@RAW.' || P_SCHEMA || '.STG_LANDING/' || P_STAGE_SUBFOLDER;
BEGIN
    EXECUTE IMMEDIATE
        'CREATE TABLE IF NOT EXISTS ' || :full_table || ' (
            raw_data    VARIANT,
            _file_name  VARCHAR,        -- lineage: which landing file this row came from
            _loaded_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
        )';

    -- AUTO_INGEST Snowpipe: as soon as a partition file lands in its subfolder, it is loaded as-is.
    -- ABORT_STATEMENT is deliberate: a corrupt/unreadable file should page the on-call DE rather
    -- than silently skipping rows in a financial fact table.
    EXECUTE IMMEDIATE
        'CREATE PIPE IF NOT EXISTS ' || :pipe_name || '
            AUTO_INGEST = TRUE
         AS
            COPY INTO ' || :full_table || ' (raw_data, _file_name)
            FROM (SELECT $1, METADATA$FILENAME FROM ' || :stage_ref || ')
            FILE_FORMAT = (TYPE = PARQUET)
            ON_ERROR = ''ABORT_STATEMENT''';

    RETURN 'created ' || :full_table || ' + ' || :pipe_name;
END;
$$;
