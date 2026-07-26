USE SSI_OEF;
GO

-- At-scale synthetic seed data for load/report testing: 10 funds, 400 OEF accounts (subset of the
-- 1000 SSI_Common customers), 10,000 trades/month for Jan-Jun 2027 (60,000 total - deliberately
-- much lower than Equity's 1,000,000/month and Derivatives' 30,000/month, since real OEF
-- subscribe/redeem volume is far lower than exchange trade volume), plus daily account_balance/
-- position snapshots (no margin - fund certificates are not traded on margin).
--
-- Same caveats as Database/Equity/07_seed_at_scale.sql's header: alternative to
-- 06_seed_sample_data.sql, requires Common/10_seed_at_scale.sql first, snapshots are independently
-- generated (not reconciled against the trade ledger), not idempotent.
SET NOCOUNT ON;
SET DATEFIRST 1;

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
-- 0. Reusable driving tables (numbers table sized for the smaller 10,000/month batch here)
-------------------------------------------------------------------------------
IF OBJECT_ID('raw.util_numbers') IS NULL
BEGIN
    ;WITH L0 AS (SELECT 1 AS c UNION ALL SELECT 1),
    L1 AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),
    L2 AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),
    L3 AS (SELECT 1 AS c FROM L2 a CROSS JOIN L2 b),
    L4 AS (SELECT 1 AS c FROM L3 a CROSS JOIN L3 b),
    Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM L4)
    SELECT TOP (10000) n
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
-- 1. Funds (10): mostly equity funds, some bond/balanced
-------------------------------------------------------------------------------
;WITH nums AS (SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects)
INSERT INTO raw.fund (fund_code, fund_name, fund_type, fund_manager, inception_date)
SELECT
    'SSIF' + RIGHT('00' + CAST(n AS VARCHAR(2)), 2),
    N'Quy ' + CASE WHEN n % 10 < 6 THEN N'Co phieu ' WHEN n % 10 < 9 THEN N'Trai phieu ' ELSE N'Can bang ' END
        + CAST(n AS NVARCHAR(2)),
    CASE WHEN n % 10 < 6 THEN 'EQUITY_FUND' WHEN n % 10 < 9 THEN 'BOND_FUND' ELSE 'BALANCED' END,
    N'SSIAM',
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 3650), '2027-01-01')
FROM nums;

-------------------------------------------------------------------------------
-- 2. Daily NAV per fund - small daily noise (funds are far less volatile than individual stocks).
--    Bond funds get an even smaller noise band than equity/balanced funds.
-------------------------------------------------------------------------------
INSERT INTO raw.fund_nav_history (nav_date, fund_id, nav_price, total_net_asset, outstanding_units)
SELECT
    td.d,
    f.fund_id,
    base.base_nav * (CASE WHEN f.fund_type = 'BOND_FUND' THEN 0.998 ELSE 0.99 END
                      + (ABS(CHECKSUM(NEWID())) % 200) / (CASE WHEN f.fund_type = 'BOND_FUND' THEN 100000.0 ELSE 20000.0 END)),
    base.base_nav * (500000 + ABS(CHECKSUM(NEWID())) % 9500000),
    500000 + ABS(CHECKSUM(NEWID())) % 9500000
FROM #trading_days td
CROSS JOIN raw.fund f
CROSS APPLY (SELECT CAST(10000 + (f.fund_id * 977) % 20000 AS DECIMAL(18,4)) AS base_nav) base;

-------------------------------------------------------------------------------
-- 3. Accounts: 400 of the 1000 SSI_Common customers get an OEF account (long-term investors -
--    moderate penetration, lower than the 800 equity accounts).
-------------------------------------------------------------------------------
INSERT INTO raw.account (account_no, customer_code, broker_code, open_date)
SELECT TOP (400)
    '0003' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY c.customer_code) AS VARCHAR(6)), 6),
    c.customer_code,
    cbh.broker_code,
    c.open_date
FROM SSI_Common.raw.customer c
JOIN SSI_Common.raw.customer_broker_history cbh
    ON cbh.customer_code = c.customer_code AND cbh.is_current = 1
WHERE c.customer_type <> 'PROPRIETARY'
ORDER BY NEWID();

-------------------------------------------------------------------------------
-- 4. Weighted draw ranges: OEF investors are less trading-skewed than equity/derivatives (buy and
--    hold), so VIP/PRIORITY weighting is milder. A couple of "flagship" funds attract most flows.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#acct_ranges') IS NOT NULL DROP TABLE #acct_ranges;
;WITH acct_weight AS (
    SELECT a.account_id, a.broker_code,
           CASE seg.segment WHEN 'VIP' THEN 4 WHEN 'PRIORITY' THEN 2 ELSE 1 END AS weight
    FROM raw.account a
    JOIN SSI_Common.raw.customer_segment_history seg
        ON seg.customer_code = a.customer_code AND seg.is_current = 1
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

IF OBJECT_ID('tempdb..#fund_ranges') IS NOT NULL DROP TABLE #fund_ranges;
;WITH fund_base AS (
    SELECT fund_id, ROW_NUMBER() OVER (ORDER BY fund_id) AS rn FROM raw.fund
),
fund_weight AS (
    SELECT fund_id, CASE WHEN rn <= 2 THEN 8 ELSE 1 END AS weight FROM fund_base
),
ranges AS (
    SELECT fund_id, weight,
        SUM(weight) OVER (ORDER BY fund_id ROWS UNBOUNDED PRECEDING) AS range_end,
        SUM(weight) OVER (ORDER BY fund_id ROWS UNBOUNDED PRECEDING) - weight + 1 AS range_start
    FROM fund_weight
)
SELECT * INTO #fund_ranges FROM ranges;
CREATE CLUSTERED INDEX ix_fund_ranges ON #fund_ranges(range_start, range_end);
DECLARE @fund_total INT = (SELECT MAX(range_end) FROM #fund_ranges);

-------------------------------------------------------------------------------
-- 5. Trade generation: 10,000 rows per month x 6 months (Jan-Jun 2027).
--    SUBSCRIBE ~55% / REDEEM ~40% / SWITCH ~5%.
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
            fr.fund_id,
            -- Draw ONE random value and test both thresholds against it - calling
            -- ABS(CHECKSUM(NEWID())) again per WHEN branch would re-roll independently each time,
            -- silently skewing the split away from the documented 55/40/5 (verified: two
            -- independent draws actually yield ~55/42.75/2.25, not 55/40/5).
            CASE WHEN tt.roll < 55 THEN 'SUBSCRIBE'
                 WHEN tt.roll < 95 THEN 'REDEEM'
                 ELSE 'SWITCH' END AS transaction_type,
            CAST(1000000 + ABS(CHECKSUM(NEWID())) % 499000000 AS DECIMAL(20,2)) AS amount,
            COALESCE(nav.nav_price, CAST(10000 + (fr.fund_id * 977) % 20000 AS DECIMAL(18,4))) AS nav_price
        FROM (SELECT TOP (10000) n FROM raw.util_numbers ORDER BY n) num
        CROSS APPLY (SELECT ABS(CHECKSUM(NEWID())) % 100 AS roll) tt
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @days_in_month) AS day_idx) di
        JOIN #month_days md ON md.rn = di.day_idx
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @acct_total) AS draw) ad
        JOIN #acct_ranges ar ON ad.draw BETWEEN ar.range_start AND ar.range_end
        JOIN raw.account a ON a.account_id = ar.account_id
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @fund_total) AS draw) fd
        JOIN #fund_ranges fr ON fd.draw BETWEEN fr.range_start AND fr.range_end
        LEFT JOIN raw.fund_nav_history nav ON nav.fund_id = fr.fund_id AND nav.nav_date = md.d
    )
    INSERT INTO raw.oef_trade (
        trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code,
        fund_id, transaction_type, quantity_unit, nav_price, amount, fee_amount,
        settlement_date, order_id, source_system
    )
    SELECT
        trade_date,
        DATEADD(SECOND, 9 * 3600 + (ABS(CHECKSUM(NEWID())) % (6 * 3600)), CAST(trade_date AS DATETIME2)),
        'OEF-' + @month_str + '-' + RIGHT('0000000' + CAST(n AS VARCHAR(7)), 7),
        account_no, customer_code, broker_code, fund_id, transaction_type,
        ROUND(amount / nav_price, 4), nav_price, amount, 0,
        DATEADD(DAY, 3, trade_date),
        'ORD-' + @month_str + '-' + CAST(n AS VARCHAR(10)),
        'OEF'
    FROM batch;

    SET @m += 1;
END;

DROP TABLE #month_days;

-------------------------------------------------------------------------------
-- 6. Daily snapshots (account_balance_daily / position_daily). No margin_loan_daily - OEF
--    certificates are not traded on margin.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#account_wealth') IS NOT NULL DROP TABLE #account_wealth;
SELECT
    a.account_id,
    CAST(1000000 + (ABS(CHECKSUM(NEWID())) % 49000000) AS DECIMAL(20,2)) AS base_cash,
    CAST(20000000 + (ABS(CHECKSUM(NEWID())) % 480000000) AS DECIMAL(20,2)) AS base_portfolio
INTO #account_wealth
FROM raw.account a;

;WITH b AS (
    SELECT
        td.d AS balance_date,
        aw.account_id,
        ROUND(aw.base_cash * (0.95 + (ABS(CHECKSUM(NEWID())) % 100) / 1000.0), 2) AS cash_balance,
        ROUND(aw.base_portfolio * (0.97 + (ABS(CHECKSUM(NEWID())) % 60) / 1000.0), 2) AS portfolio_value
    FROM #trading_days td
    CROSS JOIN #account_wealth aw
)
INSERT INTO raw.account_balance_daily (balance_date, account_id, cash_balance, portfolio_value, total_asset_value)
SELECT balance_date, account_id, cash_balance, portfolio_value, cash_balance + portfolio_value
FROM b;

-- Each account holds 1-2 funds across the period (buy-and-hold simplification).
IF OBJECT_ID('tempdb..#account_holdings') IS NOT NULL DROP TABLE #account_holdings;
;WITH acct_holding_count AS (
    SELECT account_id, 1 + (ABS(CHECKSUM(NEWID())) % 2) AS holding_count
    FROM raw.account
)
SELECT
    ahc.account_id,
    f.fund_id,
    CAST(1000000 + (ABS(CHECKSUM(NEWID())) % 199000000) AS DECIMAL(20,4)) / (10000 + (f.fund_id * 977) % 20000) AS base_units,
    CAST(10000 + (f.fund_id * 977) % 20000 AS DECIMAL(18,4)) AS base_cost
INTO #account_holdings
FROM acct_holding_count ahc
CROSS APPLY (
    SELECT TOP (ahc.holding_count) fund_id FROM raw.fund ORDER BY NEWID()
) f;

INSERT INTO raw.position_daily (position_date, account_id, fund_id, quantity_unit, avg_cost_nav, market_value)
SELECT
    td.d,
    ah.account_id,
    ah.fund_id,
    ah.base_units,
    ah.base_cost,
    ROUND(ah.base_units * COALESCE(nav.nav_price, ah.base_cost), 2)
FROM #trading_days td
CROSS JOIN #account_holdings ah
LEFT JOIN raw.fund_nav_history nav ON nav.fund_id = ah.fund_id AND nav.nav_date = td.d;

DROP TABLE #all_days;
DROP TABLE #trading_days;
DROP TABLE #acct_ranges;
DROP TABLE #fund_ranges;
DROP TABLE #account_wealth;
DROP TABLE #account_holdings;
