USE SSI_OEF;
GO

-- OEF fund certificate trade (Giao dich chung chi quy mo) - mirrored from the fund/OEF source system.
-- customer_code / broker_code are logical references to SSI_Common.raw.customer / raw.broker
-- (no cross-database FK - see note in 01_schema_init.sql).
-- Partitioned monthly by trade_date via the shared ps_oef_monthly scheme.
CREATE TABLE raw.oef_trade (
    trade_id          BIGINT        IDENTITY(1,1) NOT NULL,
    trade_date        DATE          NOT NULL,
    trade_datetime    DATETIME2(3)  NOT NULL,
    source_trade_id   VARCHAR(50)   NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NULL,
    broker_code       VARCHAR(20)   NULL,
    fund_id           INT           NOT NULL,
    transaction_type  VARCHAR(20)   NOT NULL,
    quantity_unit     NUMERIC(20,4) NOT NULL,
    nav_price         NUMERIC(18,4) NOT NULL,
    amount            NUMERIC(20,2) NOT NULL,
    fee_amount        NUMERIC(18,2) NULL CONSTRAINT df_oef_trade_fee DEFAULT (0),
    settlement_date   DATE          NULL,
    order_id          VARCHAR(50)   NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_oef_trade_source_system DEFAULT ('OEF'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_oef_trade_ingested_at DEFAULT (SYSUTCDATETIME()),
    -- account_no is a LOGICAL reference to SSI_Common.raw.account(account_no) - no FK
    CONSTRAINT pk_oef_trade PRIMARY KEY CLUSTERED (trade_id, trade_date),
    CONSTRAINT fk_oef_trade_fund FOREIGN KEY (fund_id) REFERENCES raw.fund(fund_id),
    CONSTRAINT chk_oef_trade_type CHECK (transaction_type IN ('SUBSCRIBE', 'REDEEM', 'SWITCH'))
) ON ps_oef_monthly(trade_date);
GO

-- Partition-aligned uniqueness on the natural source key
CREATE UNIQUE INDEX uq_oef_trade_source
    ON raw.oef_trade(source_system, source_trade_id, trade_date)
    ON ps_oef_monthly(trade_date);
GO

-- Non-aligned secondary indexes (do not include trade_date) - stored on [PRIMARY]
CREATE INDEX idx_oef_trade_customer ON raw.oef_trade(customer_code) ON [PRIMARY];
CREATE INDEX idx_oef_trade_broker   ON raw.oef_trade(broker_code)   ON [PRIMARY];
CREATE INDEX idx_oef_trade_fund     ON raw.oef_trade(fund_id)     ON [PRIMARY];
CREATE INDEX idx_oef_trade_account  ON raw.oef_trade(account_no)  ON [PRIMARY];
GO
