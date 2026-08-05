USE SSI_Equity;
GO

-- Optional minimal seed data for local development / ETL testing only. Not for any real environment.
-- Tickers below are fictional placeholders (not real listed companies).
-- customer_code / broker_code values below must match the corresponding rows seeded in SSI_Common.
-- account_no values reference SSI_Common.raw.account (unified account table, seeded in Common/09).
INSERT INTO raw.security (symbol, security_name, exchange, sector) VALUES
    ('ABC', N'CTCP Ngan hang ABC', 'HOSE', N'Ngan hang'),
    ('XYZ', N'CTCP Tieu dung XYZ', 'HOSE', N'Ban le - Tieu dung');

INSERT INTO raw.daily_price (price_date, security_id, close_price, reference_price, volume) VALUES
    ('2026-07-17', 1, 32.50, 32.30, 1500000),
    ('2026-07-17', 2, 68.00, 67.80, 800000);

-- NOTE: raw.account lives in SSI_Common (unified for all products), seeded there - not here.

INSERT INTO raw.equity_trade (trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code, security_id, market, side, quantity, price, amount, fee_amount) VALUES
    ('2026-07-17', '2026-07-17T09:30:00', 'EQ-000001', '0001000001', 'KH00001', 'MG001', 1, 'HOSE', 'BUY', 1000, 32.50, 32500000, 48750),
    ('2026-07-17', '2026-07-17T10:15:00', 'EQ-000002', '0001000002', 'KH00002', 'MG002', 2, 'HOSE', 'SELL', 500, 68.00, 34000000, 51000);

INSERT INTO raw.account_balance_daily (balance_date, account_no, cash_balance, portfolio_value, total_asset_value) VALUES
    ('2026-07-17', '0001000001', 50000000, 32500000, 82500000),
    ('2026-07-17', '0001000002', 20000000, 34000000, 54000000);

INSERT INTO raw.position_daily (position_date, account_no, security_id, quantity, avg_cost_price, market_value) VALUES
    ('2026-07-17', '0001000001', 1, 1000, 32.50, 32500000);