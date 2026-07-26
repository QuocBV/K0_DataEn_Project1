-- Master orchestration script for the whole SQL Server estate (4 databases).
-- Usage (sqlcmd, run from the Database/ folder):
--   sqlcmd -S <server> -d master -i 00_create_databases.sql
--   sqlcmd -S <server> -d master -i Common\run_common.sql
--   sqlcmd -S <server> -d master -i Equity\run_equity.sql
--   sqlcmd -S <server> -d master -i Derivatives\run_derivatives.sql
--   sqlcmd -S <server> -d master -i OEF\run_oef.sql
--
-- Order matters: SSI_Common must be created/seeded before the product DBs if you plan to
-- cross-check customer_id/broker_id values while seeding sample data (see seed scripts).
:r 00_create_databases.sql
:r Common\run_common.sql
:r Equity\run_equity.sql
:r Derivatives\run_derivatives.sql
:r OEF\run_oef.sql
