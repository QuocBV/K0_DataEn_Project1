USE SSI_OEF;
GO

-- OEF (Chung chi quy mo) - danh muc quy
CREATE TABLE raw.fund (
    fund_id           INT           IDENTITY(1,1) NOT NULL,
    fund_code         VARCHAR(20)   NOT NULL,
    fund_name         NVARCHAR(200) NOT NULL,
    fund_type         VARCHAR(20)   NOT NULL CONSTRAINT df_fund_type DEFAULT ('EQUITY_FUND'), -- EQUITY_FUND/BOND_FUND/BALANCED/...
    fund_manager      NVARCHAR(200) NULL,
    inception_date    DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_fund_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_fund_source_system DEFAULT ('OEF'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_fund_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_fund PRIMARY KEY CLUSTERED (fund_id),
    CONSTRAINT uq_fund_code UNIQUE (fund_code)
);
GO

-- Daily NAV history per fund - independent of individual OEF trades
CREATE TABLE raw.fund_nav_history (
    nav_date          DATE          NOT NULL,
    fund_id           INT           NOT NULL,
    nav_price         NUMERIC(18,4) NOT NULL,
    total_net_asset   NUMERIC(24,2) NULL,
    outstanding_units NUMERIC(24,4) NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_fund_nav_history_source_system DEFAULT ('OEF'),
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_fund_nav_history_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_fund_nav_history PRIMARY KEY CLUSTERED (fund_id, nav_date),
    CONSTRAINT fk_fund_nav_history_fund FOREIGN KEY (fund_id) REFERENCES raw.fund(fund_id)
);
GO
