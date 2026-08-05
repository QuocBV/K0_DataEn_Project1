USE SSI_Equity;
GO

-- Equity trade (Giao dich co so) - mirrored from the core trading source system.
-- customer_code / broker_code are logical references to SSI_Common.raw.customer / raw.broker
-- (no cross-database FK - see note in 01_schema_init.sql).
-- Partitioned monthly by trade_date via the shared ps_equity_monthly scheme.
CREATE TABLE raw.equity_trade (
    trade_id          BIGINT        IDENTITY(1,1) NOT NULL,
    trade_date        DATE          NOT NULL,
    trade_datetime    DATETIME2(3)  NOT NULL,
    source_trade_id   VARCHAR(50)   NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NULL,
    broker_code       VARCHAR(20)   NULL,
    security_id       INT           NOT NULL,
    market             VARCHAR(10)  NULL,        -- HOSE / HNX / UPCOM
    side              VARCHAR(4)    NOT NULL,
    order_type        VARCHAR(20)   NULL,
    quantity          NUMERIC(18,0) NOT NULL,
    price             NUMERIC(18,2) NOT NULL,
    amount            NUMERIC(20,2) NOT NULL,
    fee_amount        NUMERIC(18,2) NULL CONSTRAINT df_equity_trade_fee DEFAULT (0),
    tax_amount        NUMERIC(18,2) NULL CONSTRAINT df_equity_trade_tax DEFAULT (0),
    settlement_date   DATE          NULL,
    order_id          VARCHAR(50)   NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_equity_trade_source_system DEFAULT ('CORE_TRADING'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_equity_trade_ingested_at DEFAULT (SYSUTCDATETIME()),
    -- account_no is a LOGICAL reference to SSI_Common.raw.account(account_no) - no FK
    CONSTRAINT pk_equity_trade PRIMARY KEY CLUSTERED (trade_id, trade_date),
    CONSTRAINT fk_equity_trade_security FOREIGN KEY (security_id) REFERENCES raw.security(security_id),
    CONSTRAINT chk_equity_trade_side CHECK (side IN ('BUY', 'SELL'))
) ON ps_equity_monthly(trade_date);
GO

-- Partition-aligned uniqueness on the natural source key
CREATE UNIQUE INDEX uq_equity_trade_source
    ON raw.equity_trade(source_system, source_trade_id, trade_date)
    ON ps_equity_monthly(trade_date);
GO

-- Non-aligned secondary indexes (do not include trade_date) - stored on [PRIMARY]
CREATE INDEX idx_equity_trade_customer ON raw.equity_trade(customer_code) ON [PRIMARY];
CREATE INDEX idx_equity_trade_broker   ON raw.equity_trade(broker_code)   ON [PRIMARY];
CREATE INDEX idx_equity_trade_security ON raw.equity_trade(security_id) ON [PRIMARY];
CREATE INDEX idx_equity_trade_account  ON raw.equity_trade(account_no)  ON [PRIMARY];
GO
