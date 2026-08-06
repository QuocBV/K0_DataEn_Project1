USE SSI_Equity;
GO

-- At-scale synthetic seed data for load/report testing: 80 securities across 8 realistic sector
-- groups, 800 equity accounts (subset of the 1000 SSI_Common customers), 1,000,000 trades/month
-- for Jan-Jun 2027 (6,000,000 total), plus daily account_balance/position/margin snapshots over
-- the same period.
--
-- IMPORTANT ASSUMPTIONS (read before using this for anything beyond report/load testing):
-- - This is an ALTERNATIVE to 06_seed_sample_data.sql - run ONE of the two, not both (both create
--   accounts off the same SSI_Common customer range and would collide on account_no).
-- - Requires Database/Common/10_seed_at_scale.sql to have been run first (customers/brokers/segments).
-- - customer_code / broker_code (VARCHAR) are used throughout, matching SSI_Common's string keys
--   (see Database/Common/03_broker.sql / 04_customer.sql header notes) - no cross-database FK,
--   these are logical references.
-- - Securities are FICTIONAL tickers (not real listed companies) grouped into 8 realistic sector
--   buckets with sector-appropriate price ranges and exchange mix - structurally like the real
--   market (HOSE/HNX/UPCOM split, blue-chip sectors trade more) without reproducing any real
--   company's actual ticker/price data.
-- - Account/security/day selection is weighted (VIP customers and top-10 "blue chip" securities
--   trade more often) to produce realistic, non-uniform report results.
-- - Daily snapshot tables (account_balance_daily/position_daily/margin_loan_daily) are generated
--   independently (plausible random walk per account) - they are NOT reconciled against the exact
--   equity_trade ledger. Replaying 6,000,000 trades into an exact position/cash ledger is a
--   materially bigger project (full portfolio accounting engine) than synthetic seed data for
--   testing reports; do not treat these snapshots as mathematically derived from the trade history.
-- - Not idempotent: re-running this script appends another full copy of the data. Restore from a
--   backup/snapshot (or drop + recreate the database) before re-running.
SET NOCOUNT ON;
SET DATEFIRST 1;  -- Monday = 1 .. Sunday = 7, so "weekday" filtering below is independent of session settings

-- Fail loudly instead of silently generating zero trades: customer_code/broker_code are cross-
-- database logical references (no FK), so if SSI_Common hasn't been seeded yet, every downstream
-- range/weight table below ends up empty and the whole script "succeeds" with 0 rows inserted.
-- All three checks are required: raw.customer alone isn't enough - section 4's #acct_ranges (and
-- therefore every trade this script generates) also needs current customer_broker_history and
-- customer_segment_history rows, and a partial/interrupted run of 10_seed_at_scale.sql can leave
-- raw.customer populated while those are still empty.
IF NOT EXISTS (SELECT 1 FROM SSI_Common.raw.customer)
BEGIN
    RAISERROR('SSI_Common.raw.customer is empty - run Database/Common/10_seed_at_scale.sql first.', 16, 1);
    RETURN;
END;
IF NOT EXISTS (SELECT 1 FROM SSI_Common.raw.customer_broker_history WHERE is_current = 1)
BEGIN
    RAISERROR('SSI_Common.raw.customer_broker_history has no is_current=1 rows - re-run Database/Common/10_seed_at_scale.sql (it may have failed partway through).', 16, 1);
    RETURN;
END;
IF NOT EXISTS (SELECT 1 FROM SSI_Common.raw.customer_segment_history WHERE is_current = 1)
BEGIN
    RAISERROR('SSI_Common.raw.customer_segment_history has no is_current=1 rows - re-run Database/Common/10_seed_at_scale.sql (it may have failed partway through).', 16, 1);
    RETURN;
END;

-------------------------------------------------------------------------------
-- 0. Reusable driving tables: a 1,000,000-row number spine + the Jan-Jun 2027 trading calendar
-------------------------------------------------------------------------------
IF OBJECT_ID('raw.util_numbers') IS NULL
BEGIN
    ;WITH L0 AS (SELECT 1 AS c UNION ALL SELECT 1),
    L1 AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),
    L2 AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),
    L3 AS (SELECT 1 AS c FROM L2 a CROSS JOIN L2 b),
    L4 AS (SELECT 1 AS c FROM L3 a CROSS JOIN L3 b),
    L5 AS (SELECT 1 AS c FROM L4 a CROSS JOIN L4 b),
    Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM L5)
    SELECT TOP (1000000) n
    INTO raw.util_numbers
    FROM Nums
    ORDER BY n;

    ALTER TABLE raw.util_numbers ADD CONSTRAINT pk_util_numbers PRIMARY KEY CLUSTERED (n);
END;

IF OBJECT_ID('tempdb..#all_days') IS NOT NULL DROP TABLE #all_days;
;WITH L0 AS (SELECT 1 AS c UNION ALL SELECT 1),
L1 AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),
L2 AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),
L3 AS (SELECT 1 AS c FROM L2 a CROSS JOIN L2 b),
Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM L3)
SELECT TOP (181) DATEADD(DAY, n, CAST('2027-01-01' AS DATE)) AS d
INTO #all_days
FROM Nums
ORDER BY n;

IF OBJECT_ID('tempdb..#trading_days') IS NOT NULL DROP TABLE #trading_days;
SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS rn
INTO #trading_days
FROM #all_days
WHERE DATEPART(WEEKDAY, d) <= 5;
CREATE UNIQUE CLUSTERED INDEX ix_trading_days ON #trading_days(d);

-------------------------------------------------------------------------------
-- 1. Securities: 8 realistic sector groups x 10 fictional tickers each (80 total). Blue-chip
--    sectors (Banking, Real Estate) skew HOSE with higher nominal prices; smaller sectors skew
--    HNX/UPCOM with lower prices - mirrors the real market's structure without using any real
--    company's actual ticker or price.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#sector_def') IS NOT NULL DROP TABLE #sector_def;
CREATE TABLE #sector_def (
    sector_name     NVARCHAR(100),
    prefix_letter   CHAR(1),
    exchange        VARCHAR(10),
    price_min       INT,
    price_max       INT
);
INSERT INTO #sector_def (sector_name, prefix_letter, exchange, price_min, price_max) VALUES
    (N'Ngan hang',              'B', 'HOSE',  20, 45),
    (N'Bat dong san',           'D', 'HOSE',  25, 90),
    (N'Thep - Cong nghiep',     'K', 'HOSE',  15, 40),
    (N'Ban le - Tieu dung',     'R', 'HOSE',  35, 80),
    (N'Cong nghe',              'T', 'HOSE',  45, 120),
    (N'Nang luong - Dien',      'G', 'UPCOM', 15, 35),
    (N'Chung khoan',            'X', 'HNX',   10, 30),
    (N'Thuc pham - Do uong',    'F', 'UPCOM', 20, 60);

;WITH sector_rows AS (
    SELECT sector_name, prefix_letter, exchange, price_min, price_max,
           ROW_NUMBER() OVER (ORDER BY prefix_letter) AS sector_rn
    FROM #sector_def
),
seq AS (
    SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS seq_n FROM sys.all_objects
)
INSERT INTO raw.security (symbol, security_name, exchange, sector, security_type, listing_date)
SELECT
    sr.prefix_letter + 'A' + CHAR(64 + seq.seq_n),
    N'CTCP ' + sr.sector_name + N' ' + CAST(seq.seq_n AS NVARCHAR(2)),
    CASE WHEN seq.seq_n <= 6 THEN sr.exchange
         WHEN sr.exchange = 'HOSE' THEN 'HNX'
         ELSE 'UPCOM' END,   -- 6 of 10 per sector on the "main" exchange, the rest smaller-cap siblings
    sr.sector_name,
    'STOCK',
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 3650), '2027-01-01')
FROM sector_rows sr
CROSS JOIN seq;

-------------------------------------------------------------------------------
-- 2. Daily close price per security for every trading day (independent +/-5% noise around a
--    per-security base price drawn from its sector's realistic range).
-------------------------------------------------------------------------------
INSERT INTO raw.daily_price (price_date, security_id, close_price, reference_price, volume)
SELECT
    td.d,
    s.security_id,
    base.base_price * (0.95 + (ABS(CHECKSUM(NEWID())) % 1000) / 10000.0),
    base.base_price,
    1000 + ABS(CHECKSUM(NEWID())) % 2000000
FROM #trading_days td
CROSS JOIN raw.security s
CROSS APPLY (
    SELECT CAST(sd.price_min + (s.security_id * 37) % NULLIF(sd.price_max - sd.price_min, 0) AS DECIMAL(18,2)) AS base_price
    FROM #sector_def sd
    WHERE sd.sector_name = s.sector
) base;

-------------------------------------------------------------------------------
-- 3. Accounts: 800 of the 1000 SSI_Common customers get an equity account (most retail investors
--    have a cash account). broker_code is the customer's current care broker from SSI_Common.
--    NOTE: raw.account now lives in SSI_Common (unified table, product_type='EQUITY').
-------------------------------------------------------------------------------
-- Each customer may have MULTIPLE equity accounts (VIP=3, PRIORITY=2, RETAIL=1),
-- so account count >> customer count. account_no is globally unique (prefix 0001).
INSERT INTO SSI_Common.raw.account (account_no, customer_code, broker_code, product_type, open_date)
SELECT
    '0001' + RIGHT('000000' +
        CAST(ROW_NUMBER() OVER (ORDER BY sg.customer_code, sg.acc_seq) AS VARCHAR(6)), 6),
    sg.customer_code,
    sg.broker_code,
    'EQUITY',
    sg.open_date
FROM (
    SELECT c.customer_code, c.open_date, cbh.broker_code,
           COALESCE(seg.segment, 'RETAIL') AS segment,
           CASE COALESCE(seg.segment, 'RETAIL') WHEN 'VIP' THEN 3 WHEN 'PRIORITY' THEN 2 ELSE 1 END AS n_accounts
    FROM SSI_Common.raw.customer c
    JOIN SSI_Common.raw.customer_broker_history cbh
        ON cbh.customer_code = c.customer_code AND cbh.is_current = 1
    LEFT JOIN SSI_Common.raw.customer_segment_history seg
        ON seg.customer_code = c.customer_code AND seg.is_current = 1
    WHERE c.customer_type <> 'PROPRIETARY'
) sg
CROSS APPLY (
    SELECT TOP (sg.n_accounts) n AS acc_seq FROM raw.util_numbers
) seq
ORDER BY NEWID();
IF OBJECT_ID('tempdb..#acct_ranges') IS NOT NULL DROP TABLE #acct_ranges;
;WITH acct_weight AS (
    SELECT a.account_id, a.broker_code,
           CASE seg.segment WHEN 'VIP' THEN 8 WHEN 'PRIORITY' THEN 3 ELSE 1 END AS weight
    FROM SSI_Common.raw.account a
    JOIN SSI_Common.raw.customer_segment_history seg
        ON seg.customer_code = a.customer_code AND seg.is_current = 1
    WHERE a.product_type = 'EQUITY'
),
ranges AS (
    SELECT account_id, broker_code, weight,
        SUM(weight) OVER (ORDER BY account_id ROWS UNBOUNDED PRECEDING) AS range_end,
        SUM(weight) OVER (ORDER BY account_id ROWS UNBOUNDED PRECEDING) - weight + 1 AS range_start
    FROM acct_weight
)
SELECT * INTO #acct_ranges FROM ranges;
CREATE CLUSTERED INDEX ix_acct_ranges ON #acct_ranges(range_start, range_end);
DECLARE @acct_total INT = (SELECT MAX(range_end) FROM #acct_ranges);

IF OBJECT_ID('tempdb..#sec_ranges') IS NOT NULL DROP TABLE #sec_ranges;
;WITH sec_base AS (
    SELECT security_id, sector, ROW_NUMBER() OVER (PARTITION BY sector ORDER BY security_id) AS rn_in_sector
    FROM raw.security
),
sec_weight AS (
    -- the first 6 tickers per sector are the "main exchange" blue-chip siblings - weight them higher
    SELECT security_id, CASE WHEN rn_in_sector <= 6 THEN 15 ELSE 1 END AS weight
    FROM sec_base
),
ranges AS (
    SELECT security_id, weight,
        SUM(weight) OVER (ORDER BY security_id ROWS UNBOUNDED PRECEDING) AS range_end,
        SUM(weight) OVER (ORDER BY security_id ROWS UNBOUNDED PRECEDING) - weight + 1 AS range_start
    FROM sec_weight
)
SELECT * INTO #sec_ranges FROM ranges;
CREATE CLUSTERED INDEX ix_sec_ranges ON #sec_ranges(range_start, range_end);
DECLARE @sec_total INT = (SELECT MAX(range_end) FROM #sec_ranges);

-------------------------------------------------------------------------------
-- 5. Trade generation: 1,000,000 rows per month x 6 months (Jan-Jun 2027)
-------------------------------------------------------------------------------
DECLARE @m INT = 1;
DECLARE @month_start DATE, @month_end DATE, @month_str VARCHAR(6), @days_in_month INT;

WHILE @m <= 6
BEGIN
    SET @month_start = DATEFROMPARTS(2027, @m, 1);
    SET @month_end    = DATEADD(MONTH, 1, @month_start);
    SET @month_str    = FORMAT(@month_start, 'yyyyMM');

    IF OBJECT_ID('tempdb..#month_days') IS NOT NULL DROP TABLE #month_days;
    SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS rn
    INTO #month_days
    FROM #trading_days
    WHERE d >= @month_start AND d < @month_end;
    CREATE UNIQUE CLUSTERED INDEX ix_month_days ON #month_days(rn);

    SET @days_in_month = (SELECT COUNT(*) FROM #month_days);

    ;WITH batch AS (
        SELECT
            num.n,
            md.d AS trade_date,
            a.account_no, a.customer_code, a.broker_code,
            sr.security_id, sec.exchange,
            CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'BUY' ELSE 'SELL' END AS side,
            (1 + ABS(CHECKSUM(NEWID())) % 50) * 100 AS quantity,
            COALESCE(dp.close_price, 20) * (0.99 + (ABS(CHECKSUM(NEWID())) % 200) / 10000.0) AS price
        FROM (SELECT TOP (1000000) n FROM raw.util_numbers ORDER BY n) num
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @days_in_month) AS day_idx) di
        JOIN #month_days md ON md.rn = di.day_idx
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @acct_total) AS draw) ad
        JOIN #acct_ranges ar ON ad.draw BETWEEN ar.range_start AND ar.range_end
        JOIN SSI_Common.raw.account a ON a.account_id = ar.account_id AND a.product_type = 'EQUITY'
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @sec_total) AS draw) sd
        JOIN #sec_ranges sr ON sd.draw BETWEEN sr.range_start AND sr.range_end
        JOIN raw.security sec ON sec.security_id = sr.security_id
        LEFT JOIN raw.daily_price dp ON dp.security_id = sr.security_id AND dp.price_date = md.d
    )
    INSERT INTO raw.equity_trade (
        trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code,
        security_id, market, side, order_type, quantity, price, amount, fee_amount, tax_amount,
        settlement_date, order_id, source_system
    )
    SELECT
        trade_date,
        DATEADD(SECOND, 9 * 3600 + (ABS(CHECKSUM(NEWID())) % (6 * 3600)), CAST(trade_date AS DATETIME2)),
        'EQ-' + @month_str + '-' + RIGHT('0000000' + CAST(n AS VARCHAR(7)), 7),
        account_no, customer_code, broker_code, security_id, exchange, side, 'LO',
        quantity, price, quantity * price,
        ROUND(quantity * price * 0.0015, 2),
        CASE WHEN side = 'SELL' THEN ROUND(quantity * price * 0.001, 2) ELSE 0 END,
        DATEADD(DAY, 2, trade_date),
        'ORD-' + @month_str + '-' + CAST(n AS VARCHAR(10)),
        'CORE_TRADING'
    FROM batch;

    SET @m += 1;
END;

DROP TABLE #month_days;

-------------------------------------------------------------------------------
-- 6. Daily snapshots (account_balance_daily / position_daily / margin_loan_daily)
--    See the header note: independently generated, not reconciled against the trade ledger above.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#account_wealth') IS NOT NULL DROP TABLE #account_wealth;
SELECT
    a.account_no,
    CAST(5000000 + (ABS(CHECKSUM(NEWID())) % 495000000) AS DECIMAL(20,2)) AS base_cash,
    CAST(10000000 + (ABS(CHECKSUM(NEWID())) % 990000000) AS DECIMAL(20,2)) AS base_portfolio
INTO #account_wealth
FROM SSI_Common.raw.account a
WHERE a.product_type = 'EQUITY';

;WITH b AS (
    SELECT
        td.d AS balance_date,
        aw.account_no,
        ROUND(aw.base_cash * (0.9 + (ABS(CHECKSUM(NEWID())) % 200) / 1000.0), 2) AS cash_balance,
        ROUND(aw.base_portfolio * (0.9 + (ABS(CHECKSUM(NEWID())) % 200) / 1000.0), 2) AS portfolio_value
    FROM #trading_days td
    CROSS JOIN #account_wealth aw
)
INSERT INTO raw.account_balance_daily (balance_date, account_no, cash_balance, portfolio_value, total_asset_value)
SELECT balance_date, account_no, cash_balance, portfolio_value, cash_balance + portfolio_value
FROM b;

-- Each account holds a fixed set of 3-8 securities across the period (simplification - a real
-- ledger would open/close positions over time as trades settle).
IF OBJECT_ID('tempdb..#account_holdings') IS NOT NULL DROP TABLE #account_holdings;
;WITH acct_holding_count AS (
    SELECT account_no, 3 + (ABS(CHECKSUM(NEWID())) % 6) AS holding_count
    FROM SSI_Common.raw.account
    WHERE product_type = 'EQUITY'
)
SELECT
    ahc.account_no,
    s.security_id,
    (1 + ABS(CHECKSUM(NEWID())) % 50) * 100 AS base_qty,
    CAST(20 + (s.security_id * 37) % 100 AS DECIMAL(18,4)) AS base_cost
INTO #account_holdings
FROM acct_holding_count ahc
CROSS APPLY (
    SELECT TOP (ahc.holding_count) security_id FROM raw.security ORDER BY NEWID()
) s;

INSERT INTO raw.position_daily (position_date, account_no, security_id, quantity, avg_cost_price, market_value)
SELECT
    td.d,
    ah.account_no,
    ah.security_id,
    ah.base_qty,
    ah.base_cost,
    ROUND(ah.base_qty * COALESCE(dp.close_price, ah.base_cost), 2)
FROM #trading_days td
CROSS JOIN #account_holdings ah
LEFT JOIN raw.daily_price dp ON dp.security_id = ah.security_id AND dp.price_date = td.d;

-- ~30% of accounts use margin; margin_ratio spread 0.10-0.50 so ~12% of rows naturally fall below
-- the 0.15 maintenance threshold, giving rpt_margin_call_alert real rows to surface.
IF OBJECT_ID('tempdb..#margin_accounts') IS NOT NULL DROP TABLE #margin_accounts;
SELECT
    a.account_no,
    CAST(20000000 + (ABS(CHECKSUM(NEWID())) % 480000000) AS DECIMAL(20,2)) AS base_loan
INTO #margin_accounts
FROM SSI_Common.raw.account a
WHERE a.product_type = 'EQUITY' AND ABS(CHECKSUM(NEWID())) % 100 < 30;

;WITH m AS (
    SELECT
        td.d AS loan_date,
        ma.account_no,
        ROUND(ma.base_loan * (0.85 + (ABS(CHECKSUM(NEWID())) % 300) / 1000.0), 2) AS margin_loan_balance,
        CAST(0.10 + (ABS(CHECKSUM(NEWID())) % 40) / 100.0 AS DECIMAL(9,4)) AS margin_ratio
    FROM #trading_days td
    CROSS JOIN #margin_accounts ma
)
INSERT INTO raw.margin_loan_daily (loan_date, account_no, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag)
SELECT
    loan_date, account_no, margin_loan_balance, margin_ratio,
    0.15,
    CASE WHEN margin_ratio < 0.15 THEN 1 ELSE 0 END
FROM m;

DROP TABLE #all_days;
DROP TABLE #trading_days;
DROP TABLE #sector_def;
DROP TABLE #acct_ranges;
DROP TABLE #sec_ranges;
DROP TABLE #account_wealth;
DROP TABLE #account_holdings;
DROP TABLE #margin_accounts;
