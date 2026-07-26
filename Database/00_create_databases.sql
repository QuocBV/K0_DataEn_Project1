-- Creates one database per product line, per SSI's data architecture decision:
-- shared org/broker/customer data in one Common DB, each trading product isolated in its own DB.
-- Run this once, then run each subfolder's run_*.sql against its matching database.
IF DB_ID('SSI_Common') IS NULL
    CREATE DATABASE SSI_Common;
GO

IF DB_ID('SSI_Equity') IS NULL
    CREATE DATABASE SSI_Equity;
GO

IF DB_ID('SSI_Derivatives') IS NULL
    CREATE DATABASE SSI_Derivatives;
GO

IF DB_ID('SSI_OEF') IS NULL
    CREATE DATABASE SSI_OEF;
GO
