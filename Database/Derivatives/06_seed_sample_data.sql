USE SSI_Derivatives;
GO

-- Optional minimal seed data for local development / ETL testing only. Not for any real environment.
-- customer_code / broker_code values below must match the corresponding rows seeded in SSI_Common.
-- account_no values reference SSI_Common.raw.account (unified account table, seeded in Common/09).
INSERT INTO raw.derivative_contract (contract_code, underlying_symbol, contract_type, multiplier, listing_date, maturity_date) VALUES
    ('VN30F2508', 'VN30', 'INDEX_FUTURES', 100000, '2025-08-01', '2026-08-21');

INSERT INTO raw.daily_settlement_price (price_date, contract_id, settlement_price, open_interest, volume) VALUES
    ('2026-07-17', 1, 1330.50, 25000, 12000);

-- NOTE: raw.account lives in SSI_Common (unified for all products), seeded there - not here.

INSERT INTO raw.derivative_trade (trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code, contract_id, position_side, order_action, quantity, price, amount, margin_amount, fee_amount) VALUES
    ('2026-07-17', '2026-07-17T13:05:00', 'DR-000001', '0002000001', 'KH00002', 'MG002', 1, 'LONG', 'OPEN', 2, 1330.50, 266100000, 26610000, 40000);

INSERT INTO raw.account_balance_daily (balance_date, account_no, cash_balance, portfolio_value, total_asset_value) VALUES
    ('2026-07-17', '0002000001', 100000000, 0, 100000000);

INSERT INTO raw.position_daily (position_date, account_no, contract_id, position_side, quantity, avg_cost_price, market_value) VALUES
    ('2026-07-17', '0002000001', 1, 'LONG', 2, 1330.50, 266100000);

INSERT INTO raw.margin_loan_daily (loan_date, account_no, margin_loan_balance, margin_ratio, maintenance_margin_ratio, call_margin_flag) VALUES
    ('2026-07-17', '0002000001', 26610000, 0.18, 0.15, 0);