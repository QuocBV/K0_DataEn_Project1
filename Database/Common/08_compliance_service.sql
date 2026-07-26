USE SSI_Common;
GO

-- Trading alert (canh bao giao dich bat thuong) - compliance monitoring, cross-product.
-- related_trade_id/related_product_type/related_source_system point logically to a row in
-- SSI_Equity.raw.equity_trade / SSI_Derivatives.raw.derivative_trade / SSI_OEF.raw.oef_trade
-- (source_system, source_trade_id) - no DB-level FK since those live in separate databases.
CREATE TABLE raw.trading_alert (
    alert_id                   BIGINT        IDENTITY(1,1) NOT NULL,
    alert_date                 DATE          NOT NULL,
    customer_code              VARCHAR(20)   NULL,
    broker_code                VARCHAR(20)   NULL,
    related_product_type       VARCHAR(15)   NULL,     -- EQUITY / DERIVATIVES / OEF
    related_source_system      VARCHAR(50)   NULL,
    related_trade_id           VARCHAR(50)   NULL,
    alert_type                 VARCHAR(50)   NOT NULL, -- e.g. WASH_TRADE, PRICE_MANIPULATION, UNUSUAL_VOLUME
    severity                   VARCHAR(10)   NOT NULL,
    status                     VARCHAR(20)   NOT NULL CONSTRAINT df_trading_alert_status DEFAULT ('OPEN'),
    description                NVARCHAR(1000) NULL,
    source_system               VARCHAR(50)   NOT NULL CONSTRAINT df_trading_alert_source_system DEFAULT ('COMPLIANCE'),
    ingested_at                  DATETIME2(3)  NOT NULL CONSTRAINT df_trading_alert_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_trading_alert PRIMARY KEY CLUSTERED (alert_id),
    CONSTRAINT fk_trading_alert_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT fk_trading_alert_broker FOREIGN KEY (broker_code) REFERENCES raw.broker(broker_code),
    CONSTRAINT chk_trading_alert_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT chk_trading_alert_status CHECK (status IN ('OPEN', 'REVIEWING', 'CLOSED', 'ESCALATED'))
);
GO

CREATE INDEX idx_trading_alert_customer ON raw.trading_alert(customer_code);
CREATE INDEX idx_trading_alert_broker   ON raw.trading_alert(broker_code);
GO

-- Customer complaint (khieu nai KH)
CREATE TABLE raw.customer_complaint (
    complaint_id      BIGINT        IDENTITY(1,1) NOT NULL,
    customer_code     VARCHAR(20)   NOT NULL,
    broker_code       VARCHAR(20)   NULL,
    complaint_date    DATE          NOT NULL,
    channel           VARCHAR(30)   NULL,        -- HOTLINE / EMAIL / BRANCH / APP
    category          VARCHAR(50)   NULL,        -- FEE / EXECUTION / SERVICE / TECHNICAL / ...
    status            VARCHAR(20)   NOT NULL CONSTRAINT df_customer_complaint_status DEFAULT ('OPEN'),
    resolution_date   DATE          NULL,
    description       NVARCHAR(1000) NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_customer_complaint_source_system DEFAULT ('CRM'),
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_customer_complaint_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer_complaint PRIMARY KEY CLUSTERED (complaint_id),
    CONSTRAINT fk_customer_complaint_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT fk_customer_complaint_broker FOREIGN KEY (broker_code) REFERENCES raw.broker(broker_code),
    CONSTRAINT chk_customer_complaint_status CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'))
);
GO

CREATE INDEX idx_customer_complaint_customer ON raw.customer_complaint(customer_code);
CREATE INDEX idx_customer_complaint_broker   ON raw.customer_complaint(broker_code);
GO
