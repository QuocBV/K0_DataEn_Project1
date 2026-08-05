USE SSI_Equity;
GO

-- NOTE: The raw.account table has moved to SSI_Common.raw.account (04b_account.sql) - it is now a
-- UNIFIED table for all 3 product lines (Equity / Derivatives / OEF).
--
--   - account_no is the GLOBAL business key, referenced by trade tables and snapshot tables.
--   - account_id is a GLOBAL surrogate key (unique across all product DBs).
--   - product_type distinguishes the product line (each account trades exactly 1 product).
--
-- Equity-specific dimension/logical reference: this DB no longer owns account data.

-- End-of-day cash + portfolio value snapshot per account (drives AUM reporting)
-- Partitioned monthly by balance_date via the shared ps_equity_monthly scheme.
-- account_no references SSI_Common.raw.account(account_no) LOGICALLY (no cross-DB FK).
CREATE TABLE raw.account_balance_daily (
    balance_date       DATE          NOT NULL,
    account_no         VARCHAR(30)   NOT NULL,
    cash_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_cash DEFAULT (0),
    portfolio_value    NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_portfolio DEFAULT (0),
    total_asset_value  NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_total DEFAULT (0),
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_acct_balance_source_system DEFAULT ('CORE_TRADING'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_acct_balance_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account_balance_daily PRIMARY KEY CLUSTERED (account_no, balance_date)
) ON ps_equity_monthly(balance_date);
GO

CREATE INDEX idx_acct_balance_account ON raw.account_balance_daily(account_no);
GO

-- End-of-day holdings per account, per security.
-- Partitioned monthly by position_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.position_daily (
    position_date      DATE          NOT NULL,
    account_no         VARCHAR(30)   NOT NULL,
    security_id        INT           NOT NULL,
    quantity           NUMERIC(20,4) NOT NULL,
    avg_cost_price     NUMERIC(18,4) NULL,
    market_value       NUMERIC(20,2) NULL,
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_position_daily_source_system DEFAULT ('CORE_TRADING'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_position_daily_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_position_daily PRIMARY KEY CLUSTERED (account_no, security_id, position_date),
    CONSTRAINT fk_position_daily_security FOREIGN KEY (security_id) REFERENCES raw.security(security_id)
) ON ps_equity_monthly(position_date);
GO

CREATE INDEX idx_position_daily_account ON raw.position_daily(account_no);
GO

-- Daily margin loan balance and maintenance ratio per account - drives margin-call risk reporting.
-- Partitioned monthly by loan_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.margin_loan_daily (
    loan_date                 DATE          NOT NULL,
    account_no                VARCHAR(30)   NOT NULL,
    margin_loan_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_margin_loan_balance DEFAULT (0),
    margin_ratio              NUMERIC(9,4)  NULL,
    maintenance_margin_ratio  NUMERIC(9,4)  NULL,
    call_margin_flag          BIT           NOT NULL CONSTRAINT df_margin_loan_call_flag DEFAULT (0),
    source_system             VARCHAR(50)   NOT NULL CONSTRAINT df_margin_loan_source_system DEFAULT ('CORE_TRADING'),
    ingested_at               DATETIME2(3)  NOT NULL CONSTRAINT df_margin_loan_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_margin_loan_daily PRIMARY KEY CLUSTERED (account_no, loan_date)
) ON ps_equity_monthly(loan_date);
GO

CREATE INDEX idx_margin_loan_account ON raw.margin_loan_daily(account_no);
GO