-- Master script: runs all SSI_Common DDL in order via sqlcmd.
-- Usage: sqlcmd -S <server> -d master -i run_common.sql
-- Seed data (09, 10) is optional, for local/dev testing only, and mutually exclusive - uncomment
-- ONLY ONE: 09 is a tiny hand-written example, 10 is at-scale synthetic data (300 broker/CTV,
-- 1000 khach hang) used as the prerequisite for Equity/Derivatives/OEF's 07_seed_at_scale.sql.

:r 01_schema_init.sql
:r 02_organization.sql
:r 03_broker.sql
:r 04_customer.sql
:r 04b_account.sql
:r 05_customer_classification.sql
:r 06_market_reference.sql
:r 07_fee_schedule.sql
:r 08_compliance_service.sql
-- :r 09_seed_sample_data.sql
-- :r 10_seed_at_scale.sql
