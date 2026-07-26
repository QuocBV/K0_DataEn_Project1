USE SSI_Equity;
GO

-- Equity trading account. customer_code / broker_code are logical references to SSI_Common
-- (no cross-database FK - see note in 01_schema_init.sql).
CREATE TABLE raw.account (
    account_id        INT           IDENTITY(1,1) NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NOT NULL,
    broker_code       VARCHAR(20)   NULL,
    open_date         DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_account_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_account_source_system DEFAULT ('CORE_TRADING'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_account_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account PRIMARY KEY CLUSTERED (account_id),
    CONSTRAINT uq_account_no UNIQUE (account_no)
);
GO

CREATE INDEX idx_account_customer ON raw.account(customer_code);
CREATE INDEX idx_account_broker   ON raw.account(broker_code);
GO

-- End-of-day cash + portfolio value snapshot per account (drives AUM reporting)
-- Partitioned monthly by balance_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.account_balance_daily (
    balance_date       DATE          NOT NULL,
    account_id         INT           NOT NULL,
    cash_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_cash DEFAULT (0),
    portfolio_value    NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_portfolio DEFAULT (0),
    total_asset_value  NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_total DEFAULT (0),
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_acct_balance_source_system DEFAULT ('CORE_TRADING'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_acct_balance_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account_balance_daily PRIMARY KEY CLUSTERED (account_id, balance_date),
    CONSTRAINT fk_acct_balance_account FOREIGN KEY (account_id) REFERENCES raw.account(account_id)
) ON ps_equity_monthly(balance_date);
GO

-- End-of-day holdings per account, per security.
-- Partitioned monthly by position_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.position_daily (
    position_date      DATE          NOT NULL,
    account_id         INT           NOT NULL,
    security_id        INT           NOT NULL,
    quantity           NUMERIC(20,4) NOT NULL,
    avg_cost_price     NUMERIC(18,4) NULL,
    market_value       NUMERIC(20,2) NULL,
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_position_daily_source_system DEFAULT ('CORE_TRADING'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_position_daily_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_position_daily PRIMARY KEY CLUSTERED (account_id, security_id, position_date),
    CONSTRAINT fk_position_daily_account FOREIGN KEY (account_id) REFERENCES raw.account(account_id),
    CONSTRAINT fk_position_daily_security FOREIGN KEY (security_id) REFERENCES raw.security(security_id)
) ON ps_equity_monthly(position_date);
GO

-- Daily margin loan balance and maintenance ratio per account - drives margin-call risk reporting.
-- Partitioned monthly by loan_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.margin_loan_daily (
    loan_date                 DATE          NOT NULL,
    account_id                INT           NOT NULL,
    margin_loan_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_margin_loan_balance DEFAULT (0),
    margin_ratio              NUMERIC(9,4)  NULL,
    maintenance_margin_ratio  NUMERIC(9,4)  NULL,
    call_margin_flag          BIT           NOT NULL CONSTRAINT df_margin_loan_call_flag DEFAULT (0),
    source_system             VARCHAR(50)   NOT NULL CONSTRAINT df_margin_loan_source_system DEFAULT ('CORE_TRADING'),
    ingested_at               DATETIME2(3)  NOT NULL CONSTRAINT df_margin_loan_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_margin_loan_daily PRIMARY KEY CLUSTERED (account_id, loan_date),
    CONSTRAINT fk_margin_loan_account FOREIGN KEY (account_id) REFERENCES raw.account(account_id)
) ON ps_equity_monthly(loan_date);
GO
