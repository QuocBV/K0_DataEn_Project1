-- Master script: runs all SSI_Derivatives DDL in order via sqlcmd.
-- Usage: sqlcmd -S <server> -d master -i run_derivatives.sql
-- Seed data (06, 07) is optional, for local/dev testing only, and mutually exclusive - uncomment
-- ONLY ONE: 06 is a tiny hand-written example, 07 is at-scale synthetic data (10 contracts, 250
-- accounts, 30,000 trades/month Jan-Jun 2027 + daily snapshots) - requires
-- Database/Common/10_seed_at_scale.sql to have been run first.

:r 01_schema_init.sql
:r 02_partition_helper.sql
:r 03_instrument_master.sql
:r 04_account_position.sql
:r 05_derivative_trade.sql
-- :r 06_seed_sample_data.sql
-- :r 07_seed_at_scale.sql
