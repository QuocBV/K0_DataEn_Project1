USE SSI_OEF;
GO

-- Optional minimal seed data for local development / ETL testing only. Not for any real environment.
-- customer_code / broker_code values below must match the corresponding rows seeded in SSI_Common.
-- account_no values reference SSI_Common.raw.account (unified account table, seeded in Common/09).
INSERT INTO raw.fund (fund_code, fund_name, fund_type, fund_manager, inception_date) VALUES
    ('SSISCA', N'Quy Co phieu SSI', 'EQUITY_FUND', N'SSIAM', '2014-06-01');

INSERT INTO raw.fund_nav_history (nav_date, fund_id, nav_price, total_net_asset, outstanding_units) VALUES
    ('2026-07-17', 1, 28500.00, 850000000000, 29824561);

-- NOTE: raw.account lives in SSI_Common (unified for all products), seeded there - not here.

INSERT INTO raw.oef_trade (trade_date, trade_datetime, source_trade_id, account_no, customer_code, broker_code, fund_id, transaction_type, quantity_unit, nav_price, amount, fee_amount) VALUES
    ('2026-07-17', '2026-07-17T14:00:00', 'OEF-000001', '0003000001', 'KH00001', 'MG001', 1, 'SUBSCRIBE', 350.8772, 28500.00, 10000000, 0);

INSERT INTO raw.account_balance_daily (balance_date, account_no, cash_balance, portfolio_value, total_asset_value) VALUES
    ('2026-07-17', '0003000001', 0, 10000000, 10000000);

INSERT INTO raw.position_daily (position_date, account_no, fund_id, quantity_unit, avg_cost_nav, market_value) VALUES
    ('2026-07-17', '0003000001', 1, 350.8772, 28500.00, 10000000);