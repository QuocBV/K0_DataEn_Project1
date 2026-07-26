USE SSI_Common;
GO

-- Customer (Khach hang). Keyed by customer_code (string, e.g. 'KH00001') instead of a surrogate
-- int id - same rationale as raw.broker (see that file's header): customer_code is the real CIF/
-- account-root identifier from the source system, and is the only link the 3 product databases
-- have back here (no cross-database FOREIGN KEY in SQL Server).
CREATE TABLE raw.customer (
    customer_code       VARCHAR(20)   NOT NULL,
    customer_name       NVARCHAR(200) NOT NULL,
    -- customer_type: INDIVIDUAL / ORGANIZATION / PROPRIETARY (tu doanh - tai khoan tu doanh cua
    -- chinh cong ty chung khoan, tach rieng khoi KH thong thuong de bao cao dung chuan UBCKNN/HOSE).
    customer_type       VARCHAR(15)   NOT NULL,
    -- residency: DOMESTIC / FOREIGN - ket hop voi customer_type ra dung 4 nhom NDT chuan cua thi
    -- truong CK Viet Nam (NDT ca nhan/to chuc trong nuoc, NDT ca nhan/to chuc nuoc ngoai), phuc vu
    -- bao cao gia tri giao dich rong cua khoi ngoai.
    residency            VARCHAR(10)   NOT NULL CONSTRAINT df_customer_residency DEFAULT ('DOMESTIC'),
    -- id_number: personal identification data (national ID / passport / tax code) - sensitive under
    -- Luat BVDLCN 91/2025/QH15. Apply encryption/masking and access control per DLP policy;
    -- requires AIGC approval before any export (security@ssi.com.vn).
    id_number           VARCHAR(30)   NULL,
    phone               VARCHAR(20)   NULL,
    email               NVARCHAR(200) NULL,
    open_date           DATE          NULL,
    is_active           BIT           NOT NULL CONSTRAINT df_customer_is_active DEFAULT (1),
    source_system       VARCHAR(50)   NOT NULL CONSTRAINT df_customer_source_system DEFAULT ('CRM'),
    source_updated_at   DATETIME2(3)  NULL,
    ingested_at         DATETIME2(3)  NOT NULL CONSTRAINT df_customer_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer PRIMARY KEY CLUSTERED (customer_code),
    CONSTRAINT chk_customer_type CHECK (customer_type IN ('INDIVIDUAL', 'ORGANIZATION', 'PROPRIETARY')),
    CONSTRAINT chk_customer_residency CHECK (residency IN ('DOMESTIC', 'FOREIGN')),
    -- The firm's own proprietary trading account is domestic by definition
    CONSTRAINT chk_customer_proprietary_residency CHECK (customer_type <> 'PROPRIETARY' OR residency = 'DOMESTIC')
);
GO

-- Customer <-> Broker care assignment history (SCD Type 2)
CREATE TABLE raw.customer_broker_history (
    history_id          BIGINT        IDENTITY(1,1) NOT NULL,
    customer_code       VARCHAR(20)   NOT NULL,
    broker_code         VARCHAR(20)   NOT NULL,
    valid_from          DATE          NOT NULL,
    valid_to            DATE          NULL,          -- NULL = currently in effect
    is_current          BIT           NOT NULL CONSTRAINT df_cust_broker_hist_is_current DEFAULT (1),
    source_system       VARCHAR(50)   NOT NULL CONSTRAINT df_cust_broker_hist_source_system DEFAULT ('CRM'),
    ingested_at         DATETIME2(3)  NOT NULL CONSTRAINT df_cust_broker_hist_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer_broker_history PRIMARY KEY CLUSTERED (history_id),
    CONSTRAINT fk_cust_broker_hist_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT fk_cust_broker_hist_broker FOREIGN KEY (broker_code) REFERENCES raw.broker(broker_code),
    CONSTRAINT chk_cust_broker_hist_dates CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO

-- Only one is_current = 1 row allowed per customer (filtered unique index)
CREATE UNIQUE INDEX uq_customer_broker_current
    ON raw.customer_broker_history(customer_code)
    WHERE is_current = 1;
GO

CREATE INDEX idx_customer_broker_customer ON raw.customer_broker_history(customer_code, valid_from);
CREATE INDEX idx_customer_broker_broker   ON raw.customer_broker_history(broker_code);
GO

-- Helper: close the current assignment and open a new one.
-- Note: this is a convenience procedure for manual ops/testing; when ETL/CDC syncs
-- history from the source CRM, it can insert directly into customer_broker_history
-- using the source system's own historical timeline.
CREATE OR ALTER PROCEDURE raw.usp_assign_broker
    @customer_code    VARCHAR(20),
    @broker_code      VARCHAR(20),
    @effective_date   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @effective_date IS NULL
        SET @effective_date = CAST(SYSUTCDATETIME() AS DATE);

    -- Wrapped in a transaction: without this, a failure on the INSERT (e.g. @broker_code doesn't
    -- exist, violating fk_cust_broker_hist_broker) would leave the UPDATE already committed - the
    -- customer's prior assignment closed with no new current row, silently breaking the "exactly
    -- one current assignment" invariant that uq_customer_broker_current can't catch (zero rows
    -- also satisfies "at most one").
    BEGIN TRANSACTION;

    UPDATE raw.customer_broker_history
       SET valid_to   = DATEADD(DAY, -1, @effective_date),
           is_current = 0
     WHERE customer_code = @customer_code
       AND is_current = 1;

    INSERT INTO raw.customer_broker_history (customer_code, broker_code, valid_from, is_current)
    VALUES (@customer_code, @broker_code, @effective_date, 1);

    COMMIT TRANSACTION;
END;
GO
