USE SSI_OEF;
GO

-- NOTE: The raw.account table has moved to SSI_Common.raw.account (04b_account.sql) - it is now a
-- UNIFIED table for all 3 product lines (Equity / Derivatives / OEF).
--
--   - account_no is the GLOBAL business key, referenced by trade tables and snapshot tables.
--   - account_id is a GLOBAL surrogate key (unique across all product DBs).
--   - product_type distinguishes the product line (each account trades exactly 1 product).
--
-- OEF-specific dimension/logical reference: this DB no longer owns account data.

-- End-of-day cash + fund unit value snapshot per account (drives AUM reporting).
-- Partitioned monthly by balance_date via the shared ps_oef_monthly scheme.
-- account_no references SSI_Common.raw.account(account_no) LOGICALLY (no cross-DB FK).
CREATE TABLE raw.account_balance_daily (
    balance_date       DATE          NOT NULL,
    account_no         VARCHAR(30)   NOT NULL,
    cash_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_cash DEFAULT (0),
    portfolio_value    NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_portfolio DEFAULT (0),
    total_asset_value  NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_total DEFAULT (0),
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_acct_balance_source_system DEFAULT ('OEF'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_acct_balance_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account_balance_daily PRIMARY KEY CLUSTERED (account_no, balance_date)
) ON ps_oef_monthly(balance_date);
GO

CREATE INDEX idx_acct_balance_account ON raw.account_balance_daily(account_no);
GO

-- End-of-day fund unit holdings per account.
-- Partitioned monthly by position_date via the shared ps_oef_monthly scheme.
-- No margin_loan_daily here - OEF certificates are not traded on margin.
CREATE TABLE raw.position_daily (
    position_date      DATE          NOT NULL,
    account_no         VARCHAR(30)   NOT NULL,
    fund_id            INT           NOT NULL,
    quantity_unit      NUMERIC(20,4) NOT NULL,
    avg_cost_nav       NUMERIC(18,4) NULL,
    market_value       NUMERIC(20,2) NULL,
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_position_daily_source_system DEFAULT ('OEF'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_position_daily_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_position_daily PRIMARY KEY CLUSTERED (account_no, fund_id, position_date),
    CONSTRAINT fk_position_daily_fund FOREIGN KEY (fund_id) REFERENCES raw.fund(fund_id)
) ON ps_oef_monthly(position_date);
GO

CREATE INDEX idx_position_daily_account ON raw.position_daily(account_no);
GO