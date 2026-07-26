USE SSI_Equity;
GO

-- Equity (Co so) - danh muc chung khoan niem yet/dang ky giao dich
CREATE TABLE raw.security (
    security_id       INT           IDENTITY(1,1) NOT NULL,
    symbol            VARCHAR(20)   NOT NULL,
    security_name     NVARCHAR(200) NOT NULL,
    exchange          VARCHAR(10)   NOT NULL,      -- HOSE / HNX / UPCOM
    sector            NVARCHAR(100) NULL,
    security_type     VARCHAR(20)   NOT NULL CONSTRAINT df_security_type DEFAULT ('STOCK'), -- STOCK/BOND/ETF/...
    listing_date      DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_security_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_security_source_system DEFAULT ('CORE_TRADING'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_security_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_security PRIMARY KEY CLUSTERED (security_id),
    CONSTRAINT uq_security_symbol UNIQUE (symbol)
);
GO

-- Daily close/reference price for equities
CREATE TABLE raw.daily_price (
    price_date        DATE          NOT NULL,
    security_id       INT           NOT NULL,
    close_price       NUMERIC(18,2) NOT NULL,
    reference_price   NUMERIC(18,2) NULL,
    ceiling_price     NUMERIC(18,2) NULL,
    floor_price       NUMERIC(18,2) NULL,
    volume            NUMERIC(20,0) NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_daily_price_source_system DEFAULT ('CORE_TRADING'),
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_daily_price_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_daily_price PRIMARY KEY CLUSTERED (security_id, price_date),
    CONSTRAINT fk_daily_price_security FOREIGN KEY (security_id) REFERENCES raw.security(security_id)
);
GO
