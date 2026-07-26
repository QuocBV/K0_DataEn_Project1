USE SSI_Common;
GO

-- Customer acquisition (nguon KH, kenh mo TK, CTV/MG gioi thieu) - one immutable record per customer
CREATE TABLE raw.customer_acquisition (
    customer_code         VARCHAR(20)   NOT NULL,
    acquisition_channel   VARCHAR(30)   NOT NULL,   -- ONLINE / BRANCH / REFERRAL / EVENT / ...
    referral_broker_code   VARCHAR(20)   NULL,
    acquisition_date      DATE          NOT NULL,
    campaign_code         VARCHAR(30)   NULL,
    source_system         VARCHAR(50)   NOT NULL CONSTRAINT df_cust_acq_source_system DEFAULT ('CRM'),
    ingested_at           DATETIME2(3)  NOT NULL CONSTRAINT df_cust_acq_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer_acquisition PRIMARY KEY CLUSTERED (customer_code),
    CONSTRAINT fk_cust_acq_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT fk_cust_acq_broker FOREIGN KEY (referral_broker_code) REFERENCES raw.broker(broker_code)
);
GO

-- KYC risk / investor classification history (SCD Type 2)
CREATE TABLE raw.customer_risk_profile (
    history_id              BIGINT        IDENTITY(1,1) NOT NULL,
    customer_code           VARCHAR(20)   NOT NULL,
    investor_classification VARCHAR(30)  NOT NULL,   -- PROFESSIONAL / NON_PROFESSIONAL (theo UBCKNN)
    risk_level              VARCHAR(20)  NOT NULL,   -- LOW / MEDIUM / HIGH
    valid_from              DATE         NOT NULL,
    valid_to                DATE         NULL,
    is_current              BIT          NOT NULL CONSTRAINT df_cust_risk_is_current DEFAULT (1),
    source_system           VARCHAR(50)  NOT NULL CONSTRAINT df_cust_risk_source_system DEFAULT ('CRM'),
    ingested_at              DATETIME2(3) NOT NULL CONSTRAINT df_cust_risk_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer_risk_profile PRIMARY KEY CLUSTERED (history_id),
    CONSTRAINT fk_cust_risk_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT chk_cust_risk_classification CHECK (investor_classification IN ('PROFESSIONAL', 'NON_PROFESSIONAL')),
    CONSTRAINT chk_cust_risk_level CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT chk_cust_risk_dates CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO

CREATE UNIQUE INDEX uq_customer_risk_current
    ON raw.customer_risk_profile(customer_code)
    WHERE is_current = 1;
GO

-- Customer segment history (VIP / retail / ...) over time (SCD Type 2)
CREATE TABLE raw.customer_segment_history (
    history_id      BIGINT        IDENTITY(1,1) NOT NULL,
    customer_code   VARCHAR(20)   NOT NULL,
    segment         VARCHAR(20)   NOT NULL,   -- VIP / PRIORITY / RETAIL
    valid_from      DATE          NOT NULL,
    valid_to        DATE          NULL,
    is_current      BIT           NOT NULL CONSTRAINT df_cust_segment_is_current DEFAULT (1),
    source_system   VARCHAR(50)   NOT NULL CONSTRAINT df_cust_segment_source_system DEFAULT ('CRM'),
    ingested_at     DATETIME2(3)  NOT NULL CONSTRAINT df_cust_segment_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_customer_segment_history PRIMARY KEY CLUSTERED (history_id),
    CONSTRAINT fk_cust_segment_customer FOREIGN KEY (customer_code) REFERENCES raw.customer(customer_code),
    CONSTRAINT chk_cust_segment CHECK (segment IN ('VIP', 'PRIORITY', 'RETAIL')),
    CONSTRAINT chk_cust_segment_dates CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO

CREATE UNIQUE INDEX uq_customer_segment_current
    ON raw.customer_segment_history(customer_code)
    WHERE is_current = 1;
GO

-- Helper procedures: close current record and open a new one (same pattern as usp_assign_broker)
CREATE OR ALTER PROCEDURE raw.usp_set_customer_risk_profile
    @customer_code            VARCHAR(20),
    @investor_classification  VARCHAR(30),
    @risk_level               VARCHAR(20),
    @effective_date           DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @effective_date IS NULL
        SET @effective_date = CAST(SYSUTCDATETIME() AS DATE);

    -- Transaction: see usp_assign_broker's comment for why close+open must not partially commit.
    BEGIN TRANSACTION;

    UPDATE raw.customer_risk_profile
       SET valid_to   = DATEADD(DAY, -1, @effective_date),
           is_current = 0
     WHERE customer_code = @customer_code
       AND is_current = 1;

    INSERT INTO raw.customer_risk_profile (customer_code, investor_classification, risk_level, valid_from, is_current)
    VALUES (@customer_code, @investor_classification, @risk_level, @effective_date, 1);

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE raw.usp_set_customer_segment
    @customer_code   VARCHAR(20),
    @segment         VARCHAR(20),
    @effective_date  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @effective_date IS NULL
        SET @effective_date = CAST(SYSUTCDATETIME() AS DATE);

    -- Transaction: see usp_assign_broker's comment for why close+open must not partially commit.
    BEGIN TRANSACTION;

    UPDATE raw.customer_segment_history
       SET valid_to   = DATEADD(DAY, -1, @effective_date),
           is_current = 0
     WHERE customer_code = @customer_code
       AND is_current = 1;

    INSERT INTO raw.customer_segment_history (customer_code, segment, valid_from, is_current)
    VALUES (@customer_code, @segment, @effective_date, 1);

    COMMIT TRANSACTION;
END;
GO
