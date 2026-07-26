USE SSI_Derivatives;
GO

-- Derivatives (Phai sinh) - danh muc hop dong (VN30F..., bond futures, ...)
CREATE TABLE raw.derivative_contract (
    contract_id       INT           IDENTITY(1,1) NOT NULL,
    contract_code     VARCHAR(20)   NOT NULL,
    underlying_symbol VARCHAR(20)   NULL,           -- e.g. VN30 for a VN30F contract
    contract_type     VARCHAR(20)   NOT NULL CONSTRAINT df_derivative_contract_type DEFAULT ('INDEX_FUTURES'),
    multiplier        NUMERIC(18,2) NOT NULL CONSTRAINT df_derivative_contract_multiplier DEFAULT (100000),
    listing_date      DATE          NULL,
    maturity_date     DATE          NULL,
    is_active         BIT           NOT NULL CONSTRAINT df_derivative_contract_is_active DEFAULT (1),
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_derivative_contract_source_system DEFAULT ('DERIVATIVES'),
    source_updated_at DATETIME2(3)  NULL,
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_derivative_contract_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_derivative_contract PRIMARY KEY CLUSTERED (contract_id),
    CONSTRAINT uq_derivative_contract_code UNIQUE (contract_code)
);
GO

-- Daily settlement price per contract - used for daily mark-to-market / margin calculation
CREATE TABLE raw.daily_settlement_price (
    price_date        DATE          NOT NULL,
    contract_id       INT           NOT NULL,
    settlement_price  NUMERIC(18,2) NOT NULL,
    open_interest     NUMERIC(20,0) NULL,
    volume            NUMERIC(20,0) NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_daily_settlement_price_source_system DEFAULT ('DERIVATIVES'),
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_daily_settlement_price_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_daily_settlement_price PRIMARY KEY CLUSTERED (contract_id, price_date),
    CONSTRAINT fk_daily_settlement_price_contract FOREIGN KEY (contract_id) REFERENCES raw.derivative_contract(contract_id)
);
GO
