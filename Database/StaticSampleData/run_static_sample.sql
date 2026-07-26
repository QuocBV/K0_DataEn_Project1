-- Master script: runs all StaticSampleData files in dependency order via sqlcmd.
-- Usage: sqlcmd -S <server> -d master -i run_static_sample.sql
--
-- This is the THIRD seed-data option (see generate_static_sample.py for how these files were
-- produced), alongside each product's 06_seed_sample_data.sql (tiny hand-written demo) and
-- 07_seed_at_scale.sql / Common's 10_seed_at_scale.sql (full at-scale generator: 1M/30k/10k
-- trades per month). Use StaticSampleData when you want a realistic, business-rule-correct
-- dataset (~1000 rows/table/month cap on trade tables) as plain literal INSERT statements -
-- no server-side randomization, fully reproducible, safe to diff/review/open directly.
--
-- Prerequisite: schema DDL must already exist (run Common/Equity/Derivatives/OEF's
-- 01_schema_init.sql etc. first, e.g. via Database/run_all.sql - just skip its commented-out
-- seed-data lines and run this instead).
--
-- Mutually exclusive with 09/10_seed_at_scale.sql and each product's 06/07 seed scripts - only
-- one seed-data option should be loaded into a given set of databases at a time.

:r 01_common_sample.sql
:r 02_equity_sample.sql
:r 03_derivatives_sample.sql
:r 04_oef_sample.sql
