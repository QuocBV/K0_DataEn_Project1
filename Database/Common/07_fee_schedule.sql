USE SSI_Common;
GO

-- Fee/commission rate schedule, shared across the 3 product lines, effective-dated so
-- historical commission reports stay accurate even after rates change.
CREATE TABLE raw.fee_schedule (
    fee_schedule_id     INT           IDENTITY(1,1) NOT NULL,
    product_type        VARCHAR(15)   NOT NULL,        -- EQUITY / DERIVATIVES / OEF
    broker_tier         VARCHAR(20)   NULL,             -- NULL = default rate applies to all tiers
    fee_rate            NUMERIC(9,6)  NOT NULL,         -- trading fee rate charged to customer
    commission_rate      NUMERIC(9,6)  NOT NULL,        -- share of fee/revenue paid out as broker commission
    effective_from        DATE          NOT NULL,
    effective_to          DATE          NULL,
    is_current             BIT           NOT NULL CONSTRAINT df_fee_schedule_is_current DEFAULT (1),
    source_system            VARCHAR(50)   NOT NULL CONSTRAINT df_fee_schedule_source_system DEFAULT ('FINANCE'),
    ingested_at               DATETIME2(3)  NOT NULL CONSTRAINT df_fee_schedule_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_fee_schedule PRIMARY KEY CLUSTERED (fee_schedule_id),
    CONSTRAINT chk_fee_schedule_product CHECK (product_type IN ('EQUITY', 'DERIVATIVES', 'OEF'))
);
GO

CREATE INDEX idx_fee_schedule_product ON raw.fee_schedule(product_type, broker_tier);
GO

-- Only one "current" rate row per (product_type, broker_tier) - without this, two overlapping
-- is_current=1 rows for the same product/tier make rate lookups ambiguous (which one applies?).
-- SQL Server treats NULL broker_tier as equal to NULL for uniqueness purposes here, so this also
-- correctly allows only one current NULL-tier ("default for all tiers") row per product_type.
CREATE UNIQUE INDEX uq_fee_schedule_current ON raw.fee_schedule(product_type, broker_tier) WHERE is_current = 1;
GO

-- Management override commission rate, for Truong phong / Giam doc chi nhanh, paid on top of
-- individual broker commission based on their department's/branch's total revenue. Effective-dated
-- for the same reason as fee_schedule. management_level HEAD_OF_DEPARTMENT applies the rate to the
-- department's total revenue; BRANCH_DIRECTOR applies it to the branch's total revenue.
CREATE TABLE raw.management_commission_schedule (
    schedule_id         INT           IDENTITY(1,1) NOT NULL,
    management_level    VARCHAR(20)   NOT NULL,     -- HEAD_OF_DEPARTMENT / BRANCH_DIRECTOR
    commission_rate     NUMERIC(9,6)  NOT NULL,     -- % of subordinate revenue paid as override commission
    effective_from       DATE          NOT NULL,
    effective_to         DATE          NULL,
    is_current            BIT           NOT NULL CONSTRAINT df_mgmt_comm_is_current DEFAULT (1),
    source_system          VARCHAR(50)   NOT NULL CONSTRAINT df_mgmt_comm_source_system DEFAULT ('FINANCE'),
    ingested_at             DATETIME2(3)  NOT NULL CONSTRAINT df_mgmt_comm_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_management_commission_schedule PRIMARY KEY CLUSTERED (schedule_id),
    CONSTRAINT chk_mgmt_comm_level CHECK (management_level IN ('HEAD_OF_DEPARTMENT', 'BRANCH_DIRECTOR'))
);
GO

-- Only one "current" rate row per management_level - same rationale as uq_fee_schedule_current.
CREATE UNIQUE INDEX uq_mgmt_comm_current ON raw.management_commission_schedule(management_level) WHERE is_current = 1;
GO
