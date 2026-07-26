USE SSI_Derivatives;
GO

-- At-scale synthetic seed data for load/report testing: 10 futures contracts (rolling front-month
-- liquidity pattern), 250 derivatives accounts (subset of the 1000 SSI_Common customers),
-- 30,000 trades/month for Jan-Jun 2027 (180,000 total), plus daily account_balance/position/
-- margin snapshots over the same period. Trades are assigned to accounts via the weighted random
-- draw in section 4 below (VIP/PRIORITY customers pull more volume than retail, not a flat split).
--
-- IMPORTANT ASSUMPTIONS (read Database/Equity/07_seed_at_scale.sql's header first - same caveats
-- apply: alternative to 06_seed_sample_data.sql, requires Common/10_seed_at_scale.sql first,
-- snapshots are independently generated (not reconciled against the trade ledger), not idempotent.
--
-- Derivatives-specific realism: at any point in time, the "front month" contract (nearest
-- maturity) carries most of the trading volume, the next month a little, and further months
-- almost none - this is modeled by rebuilding the contract weighting inside the per-month loop
-- instead of a single static weight table (unlike Equity's securities, which don't roll monthly).
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
-- 0. Reusable driving tables
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
    SELECT TOP (30000) n
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
-- 1. Contracts: one per month from 2026-11 to 2027-08 (10), maturity = last day of that month
-------------------------------------------------------------------------------
;WITH nums AS (SELECT TOP (10) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects)
INSERT INTO raw.derivative_contract (contract_code, underlying_symbol, contract_type, multiplier, listing_date, maturity_date)
SELECT
    'VN30F' + FORMAT(DATEADD(MONTH, n, '2026-11-01'), 'yyMM'),
    'VN30',
    'INDEX_FUTURES',
    100000,
    DATEADD(MONTH, n - 3, '2026-11-01'),
    EOMONTH(DATEADD(MONTH, n, '2026-11-01'))
FROM nums;

-------------------------------------------------------------------------------
-- 2. Daily settlement price per contract, from listing_date to maturity_date, random walk-ish
--    around a shared VN30-index level (~1300) with small daily noise.
-------------------------------------------------------------------------------
INSERT INTO raw.daily_settlement_price (price_date, contract_id, settlement_price, open_interest, volume)
SELECT
    td.d,
    c.contract_id,
    1300 * (0.95 + (ABS(CHECKSUM(NEWID())) % 1000) / 10000.0),
    5000 + ABS(CHECKSUM(NEWID())) % 45000,
    500 + ABS(CHECKSUM(NEWID())) % 50000
FROM #trading_days td
JOIN raw.derivative_contract c ON td.d BETWEEN c.listing_date AND c.maturity_date;

-------------------------------------------------------------------------------
-- 3. Accounts: 250 of the 1000 SSI_Common customers get a derivatives account (a smaller, more
--    sophisticated subset than equity's 800 - overlap with equity accounts is expected/desired,
--    it's what rpt_customer_cross_sell measures).
-------------------------------------------------------------------------------
INSERT INTO raw.account (account_no, customer_code, broker_code, open_date)
SELECT TOP (250)
    '0002' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY c.customer_code) AS VARCHAR(6)), 6),
    c.customer_code,
    cbh.broker_code,
    c.open_date
FROM SSI_Common.raw.customer c
JOIN SSI_Common.raw.customer_broker_history cbh
    ON cbh.customer_code = c.customer_code AND cbh.is_current = 1
WHERE c.customer_type <> 'PROPRIETARY'
ORDER BY NEWID();

-------------------------------------------------------------------------------
-- 4. Weighted account ranges (VIP/PRIORITY trade derivatives noticeably more than retail - more
--    skewed than equity, since derivatives is a more sophisticated/active-trader product).
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#acct_ranges') IS NOT NULL DROP TABLE #acct_ranges;
;WITH acct_weight AS (
    SELECT a.account_id, a.broker_code,
           CASE seg.segment WHEN 'VIP' THEN 10 WHEN 'PRIORITY' THEN 3 ELSE 1 END AS weight
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

-------------------------------------------------------------------------------
-- 5. Trade generation: 30,000 rows per month x 6 months (Jan-Jun 2027). Contract weighting is
--    rebuilt every iteration: front month (nearest maturity >= month start) gets most volume, next
--    month a little, everything else almost none.
-------------------------------------------------------------------------------
DECLARE @m INT = 1;
DECLARE @month_start DATE, @month_end DATE, @month_str VARCHAR(6), @days_in_month INT, @contract_total INT;

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

    IF OBJECT_ID('tempdb..#contract_ranges') IS NOT NULL DROP TABLE #contract_ranges;
    ;WITH active AS (
        SELECT contract_id, maturity_date,
               ROW_NUMBER() OVER (ORDER BY maturity_date) AS rn
        FROM raw.derivative_contract
        WHERE maturity_date >= @month_start
    ),
    weighted AS (
        SELECT contract_id, CASE WHEN rn = 1 THEN 15 WHEN rn = 2 THEN 4 ELSE 1 END AS weight
        FROM active
    ),
    ranges AS (
        SELECT contract_id, weight,
            SUM(weight) OVER (ORDER BY contract_id ROWS UNBOUNDED PRECEDING) AS range_end,
            SUM(weight) OVER (ORDER BY contract_id ROWS UNBOUNDED PRECEDING) - weight + 1 AS range_start
        FROM weighted
    )
    SELECT * INTO #contract_ranges FROM ranges;
    CREATE CLUSTERED INDEX ix_contract_ranges ON #contract_ranges(range_start, range_end);
    SET @contract_total = (SELECT MAX(range_end) FROM #contract_ranges);

    ;WITH batch AS (
        SELECT
            num.n,
            md.d AS trade_date,
            a.account_no, a.customer_code, a.broker_code,
            cr.contract_id,
            dc.multiplier,
            CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'LONG' ELSE 'SHORT' END AS position_side,
            CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 6 THEN 'OPEN' ELSE 'CLOSE' END AS order_action,
            1 + ABS(CHECKSUM(NEWID())) % 20 AS quantity,
            COALESCE(dsp.settlement_price, 1300) * (0.995 + (ABS(CHECKSUM(NEWID())) % 100) / 10000.0) AS price
        FROM (SELECT TOP (30000) n FROM raw.util_numbers ORDER BY n) num
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @days_in_month) AS day_idx) di
        JOIN #month_days md ON md.rn = di.day_idx
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @acct_total) AS draw) ad
        JOIN #acct_ranges ar ON ad.draw BETWEEN ar.range_start AND ar.range_end
        JOIN raw.account a ON a.account_id = ar.account_id
        CROSS APPLY (SELECT 1 + (ABS(CHECKSUM(NEWID())) % @contract_total) AS draw) cd
        JOIN #contract_ranges cr ON cd.draw BETWEEN cr.range_start AND cr.range_end
        -- Join the contract's own multiplier instead of hardcoding 100000 below: every generated
        -- contract happens to use 100000 today, but amount/margin/fee must stay correct if that
        -- ever stops being true (real VN30F vs bond-future contracts can differ).
        JOIN raw.derivative_contract dc ON dc.contract_id = cr.contract_id
        LEFT JOIN raw.daily_settlement_price dsp ON dsp.contract_id = cr.contract_id AND dsp.price_date = md.d
    )
    INSERT INTO raw.derivative_trade (
        trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code,
        contract_id, position_side, order_action, quantity, price, amount, margin_amount,
        fee_amount, settlement_date, order_id, source_system
    )
    SELECT
        trade_date,
        DATEADD(SECOND, 9 * 3600 + (ABS(CHECKSUM(NEWID())) % (6 * 3600)), CAST(trade_date AS DATETIME2)),
        'DR-' + @month_str + '-' + RIGHT('0000000' + CAST(n AS VARCHAR(7)), 7),
        account_no, customer_code, broker_code, contract_id, position_side, order_action,
        quantity, price, quantity * price * multiplier,
        ROUND(quantity * price * multiplier * 0.15, 2),
        ROUND(quantity * price * multiplier * 0.0002, 2),
        DATEADD(DAY, 2, trade_date),
        'ORD-' + @month_str + '-' + CAST(n AS VARCHAR(10)),
        'DERIVATIVES'
    FROM batch;

    SET @m += 1;
END;

DROP TABLE #month_days;
DROP TABLE #contract_ranges;

-------------------------------------------------------------------------------
-- 6. Daily snapshots. Every derivatives account is margin-based (futures require margin), unlike
--    equity where only ~30% of accounts use margin.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#account_wealth') IS NOT NULL DROP TABLE #account_wealth;
SELECT
    a.account_id,
    CAST(20000000 + (ABS(CHECKSUM(NEWID())) % 480000000) AS DECIMAL(20,2)) AS base_cash,
    CAST(10000000 + (ABS(CHECKSUM(NEWID())) % 290000000) AS DECIMAL(20,2)) AS base_portfolio
INTO #account_wealth
FROM raw.account a;

;WITH b AS (
    SELECT
        td.d AS balance_date,
        aw.account_id,
        ROUND(aw.base_cash * (0.9 + (ABS(CHECKSUM(NEWID())) % 200) / 1000.0), 2) AS cash_balance,
        ROUND(aw.base_portfolio * (0.9 + (ABS(CHECKSUM(NEWID())) % 200) / 1000.0), 2) AS portfolio_value
    FROM #trading_days td
    CROSS JOIN #account_wealth aw
)
INSERT INTO raw.account_balance_daily (balance_date, account_id, cash_balance, portfolio_value, total_asset_value)
SELECT balance_date, account_id, cash_balance, portfolio_value, cash_balance + portfolio_value
FROM b;

-- Each account holds 1-3 open contract positions across the period (simplification). Candidates
-- are restricted to contracts that haven't matured by the END of the snapshot window
-- (2027-06-30) - otherwise a held position could sit on an already-expired contract for the rest
-- of the period, with no settlement price ever available and a market_value frozen at base_cost.
IF OBJECT_ID('tempdb..#account_holdings') IS NOT NULL DROP TABLE #account_holdings;
;WITH acct_holding_count AS (
    SELECT account_id, 1 + (ABS(CHECKSUM(NEWID())) % 3) AS holding_count
    FROM raw.account
)
SELECT
    ahc.account_id,
    c.contract_id,
    c.multiplier,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'LONG' ELSE 'SHORT' END AS position_side,
    1 + ABS(CHECKSUM(NEWID())) % 20 AS base_qty,
    CAST(1300 AS DECIMAL(18,4)) AS base_cost
INTO #account_holdings
FROM acct_holding_count ahc
CROSS APPLY (
    SELECT TOP (ahc.holding_count) contract_id, multiplier
    FROM raw.derivative_contract
    WHERE maturity_date >= '2027-06-30'
    ORDER BY NEWID()
) c;

INSERT INTO raw.position_daily (position_date, account_id, contract_id, position_side, quantity, avg_cost_price, market_value)
SELECT
    td.d,
    ah.account_id,
    ah.contract_id,
    ah.position_side,
    ah.base_qty,
    ah.base_cost,
    ROUND(ah.base_qty * COALESCE(dsp.settlement_price, ah.base_cost) * ah.multiplier, 2)
FROM #trading_days td
CROSS JOIN #account_holdings ah
LEFT JOIN raw.daily_settlement_price dsp ON dsp.contract_id = ah.contract_id AND dsp.price_date = td.d;

;WITH m AS (
    SELECT
        td.d AS loan_date,
        aw.account_id,
        ROUND(aw.base_portfolio * 0.15 * (0.85 + (ABS(CHECKSUM(NEWID())) % 300) / 1000.0), 2) AS margin_loan_balance,
        CAST(0.10 + (ABS(CHECKSUM(NEWID())) % 40) / 100.0 AS DECIMAL(9,4)) AS margin_ratio
    FROM #trading_days td
    CROSS JOIN #account_wealth aw
)
INSERT INTO raw.margin_loan_daily (loan_date, account_id, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag)
SELECT
    loan_date, account_id, margin_loan_balance, margin_ratio,
    0.15,
    CASE WHEN margin_ratio < 0.15 THEN 1 ELSE 0 END
FROM m;

DROP TABLE #all_days;
DROP TABLE #trading_days;
DROP TABLE #acct_ranges;
DROP TABLE #account_wealth;
DROP TABLE #account_holdings;
