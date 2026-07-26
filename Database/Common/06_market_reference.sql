USE SSI_Common;
GO

-- Market index level per day (VN-Index, VN30, HNX-Index, ...) - shared benchmark used by both
-- Equity performance reports and Derivatives (VN30F underlying) reports.
CREATE TABLE raw.market_index_price (
    price_date        DATE          NOT NULL,
    index_code        VARCHAR(20)   NOT NULL,
    close_value       NUMERIC(18,2) NOT NULL,
    change_percent    NUMERIC(9,4)  NULL,
    volume            NUMERIC(20,0) NULL,
    source_system     VARCHAR(50)   NOT NULL CONSTRAINT df_market_index_price_source_system DEFAULT ('MARKET_DATA'),
    ingested_at       DATETIME2(3)  NOT NULL CONSTRAINT df_market_index_price_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_market_index_price PRIMARY KEY CLUSTERED (index_code, price_date)
);
GO
