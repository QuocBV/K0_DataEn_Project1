USE SSI_Common;
GO

-- Unified customer account table shared by all 3 product lines (Equity / Derivatives / OEF).
-- This is the SINGLE source of truth for customer accounts in the whole platform.
--
-- 1 customer -> N accounts (1:N via customer_code).
-- 1 account -> exactly 1 product line (enforced by product_type CHECK).
--
-- account_id is a GLOBAL surrogate key (unique across the whole platform, unlike the
-- old per-database account_id which collided across SSI_Equity / SSI_Derivatives / SSI_OEF).
-- account_no is the global business key; trade tables and snapshot tables reference this value.
--
-- product DBs do NOT create their own raw.account table anymore. They reference
-- SSI_Common.raw.account(account_no) logically (no cross-database FK - see 01_schema_init.sql).
CREATE TABLE raw.account (
    account_id        INT           IDENTITY(1,1) NOT NULL,
    account_no        VARCHAR(30)   NOT NULL,
    customer_code     VARCHAR(20)   NOT NULL,
    broker_code       VARCHAR(20)   NULL,
    product_type      VARCHAR(20)   NOT NULL,
    open_date         DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_account_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_account_source_system DEFAULT ('CORE_TRADING'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_account_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_account PRIMARY KEY CLUSTERED (account_id),
    CONSTRAINT uq_account_no UNIQUE (account_no),
    CONSTRAINT chk_account_product_type CHECK (product_type IN ('EQUITY', 'DERIVATIVES', 'OEF'))
);
GO

-- 1 customer -> many accounts
CREATE INDEX idx_account_customer ON raw.account(customer_code);
-- broker assignment lookup
CREATE INDEX idx_account_broker   ON raw.account(broker_code);
-- per-product line lookup
CREATE INDEX idx_account_product  ON raw.account(product_type);
GO