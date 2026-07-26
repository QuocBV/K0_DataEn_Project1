USE SSI_OEF;
GO

-- OEF trading account. customer_code / broker_code are logical references to SSI_Common
-- (no cross-database FK - see note in 01_schema_init.sql).
CREATE TABLE raw.account (
    account_id        INT           IDENTITY(1,1) NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NOT NULL,
    broker_code       VARCHAR(20)   NULL,
    open_date         DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_account_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_account_source_system DEFAULT ('OEF'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_account_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account PRIMARY KEY CLUSTERED (account_id),
    CONSTRAINT uq_account_no UNIQUE (account_no)
);
GO

CREATE INDEX idx_account_customer ON raw.account(customer_code);
CREATE INDEX idx_account_broker   ON raw.account(broker_code);
GO

-- End-of-day cash + fund unit value snapshot per account (drives AUM reporting).
-- Partitioned monthly by balance_date via the shared ps_oef_monthly scheme.
CREATE TABLE raw.account_balance_daily (
    balance_date       DATE          NOT NULL,
    account_id         INT           NOT NULL,
    cash_balance       NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_cash DEFAULT (0),
    portfolio_value    NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_portfolio DEFAULT (0),
    total_asset_value  NUMERIC(20,2) NOT NULL CONSTRAINT df_acct_balance_total DEFAULT (0),
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_acct_balance_source_system DEFAULT ('OEF'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_acct_balance_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account_balance_daily PRIMARY KEY CLUSTERED (account_id, balance_date),
    CONSTRAINT fk_acct_balance_account FOREIGN KEY (account_id) REFERENCES raw.account(account_id)
) ON ps_oef_monthly(balance_date);
GO

-- End-of-day fund unit holdings per account.
-- Partitioned monthly by position_date via the shared ps_oef_monthly scheme.
-- No margin_loan_daily here - OEF certificates are not traded on margin.
CREATE TABLE raw.position_daily (
    position_date      DATE          NOT NULL,
    account_id         INT           NOT NULL,
    fund_id            INT           NOT NULL,
    quantity_unit      NUMERIC(20,4) NOT NULL,
    avg_cost_nav       NUMERIC(18,4) NULL,
    market_value       NUMERIC(20,2) NULL,
    source_system      VARCHAR(50)   NOT NULL CONSTRAINT df_position_daily_source_system DEFAULT ('OEF'),
    ingested_at        DATETIME2(3)  NOT NULL CONSTRAINT df_position_daily_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_position_daily PRIMARY KEY CLUSTERED (account_id, fund_id, position_date),
    CONSTRAINT fk_position_daily_account FOREIGN KEY (account_id) REFERENCES raw.account(account_id),
    CONSTRAINT fk_position_daily_fund FOREIGN KEY (fund_id) REFERENCES raw.fund(fund_id)
) ON ps_oef_monthly(position_date);
GO
