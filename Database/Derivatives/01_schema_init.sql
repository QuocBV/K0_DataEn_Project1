-- SSI_Derivatives: derivatives (phai sinh) trading data - instrument master, trades, accounts/positions.
-- Raw/source layer: mirror tu he thong derivatives, chua qua ETL/transform.
-- customer_id / broker_id below are logical references to SSI_Common.raw.customer / raw.broker.
-- SQL Server does not support cross-database FOREIGN KEY constraints, so referential integrity
-- against SSI_Common is enforced at the ETL/application layer, not by a DB constraint here.
USE SSI_Derivatives;
GO

CREATE SCHEMA raw AUTHORIZATION dbo;
GO
