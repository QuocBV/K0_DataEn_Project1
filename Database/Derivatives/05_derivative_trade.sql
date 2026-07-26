USE SSI_Derivatives;
GO

-- Derivative trade (Giao dich phai sinh) - mirrored from the derivatives source system.
-- customer_code / broker_code are logical references to SSI_Common.raw.customer / raw.broker
-- (no cross-database FK - see note in 01_schema_init.sql).
-- Partitioned monthly by trade_date via the shared ps_derivatives_monthly scheme.
CREATE TABLE raw.derivative_trade (
    trade_id          BIGINT        IDENTITY(1,1) NOT NULL,
    trade_date        DATE          NOT NULL,
    trade_datetime    DATETIME2(3)  NOT NULL,
    source_trade_id   VARCHAR(50)   NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NULL,
    broker_code       VARCHAR(20)   NULL,
    contract_id       INT           NOT NULL,
    position_side     VARCHAR(5)    NOT NULL,
    order_action      VARCHAR(10)   NOT NULL,
    quantity          NUMERIC(18,0) NOT NULL,
    price             NUMERIC(18,2) NOT NULL,
    amount            NUMERIC(20,2) NOT NULL,
    margin_amount     NUMERIC(20,2) NULL,
    fee_amount        NUMERIC(18,2) NULL CONSTRAINT df_derivative_trade_fee DEFAULT (0),
    settlement_date   DATE          NULL,
    order_id          VARCHAR(50)   NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_derivative_trade_source_system DEFAULT ('DERIVATIVES'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_derivative_trade_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_derivative_trade PRIMARY KEY CLUSTERED (trade_id, trade_date),
    CONSTRAINT fk_derivative_trade_contract FOREIGN KEY (contract_id) REFERENCES raw.derivative_contract(contract_id),
    CONSTRAINT fk_derivative_trade_account FOREIGN KEY (account_no) REFERENCES raw.account(account_no),
    CONSTRAINT chk_derivative_trade_side CHECK (position_side IN ('LONG', 'SHORT')),
    CONSTRAINT chk_derivative_trade_action CHECK (order_action IN ('OPEN', 'CLOSE'))
) ON ps_derivatives_monthly(trade_date);
GO

-- Partition-aligned uniqueness on the natural source key
CREATE UNIQUE INDEX uq_derivative_trade_source
    ON raw.derivative_trade(source_system, source_trade_id, trade_date)
    ON ps_derivatives_monthly(trade_date);
GO

-- Non-aligned secondary indexes (do not include trade_date) - stored on [PRIMARY]
CREATE INDEX idx_derivative_trade_customer ON raw.derivative_trade(customer_code) ON [PRIMARY];
CREATE INDEX idx_derivative_trade_broker   ON raw.derivative_trade(broker_code)   ON [PRIMARY];
CREATE INDEX idx_derivative_trade_contract ON raw.derivative_trade(contract_id) ON [PRIMARY];
CREATE INDEX idx_derivative_trade_account  ON raw.derivative_trade(account_no)  ON [PRIMARY];
GO
