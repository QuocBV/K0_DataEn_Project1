USE SSI_OEF;
GO

-- Shared partition function/scheme for oef_trade and the daily account/position snapshot
-- tables, partitioned monthly by date. All partitions map to [PRIMARY] here for simplicity;
-- split across filegroups later if needed.
CREATE PARTITION FUNCTION pf_oef_monthly (DATE)
AS RANGE RIGHT FOR VALUES (
    '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01',
    '2026-05-01', '2026-06-01', '2026-07-01', '2026-08-01',
    '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01',
    '2027-01-01', '2027-02-01', '2027-03-01', '2027-04-01',
    '2027-05-01', '2027-06-01', '2027-07-01'
);
GO

CREATE PARTITION SCHEME ps_oef_monthly
AS PARTITION pf_oef_monthly ALL TO ([PRIMARY]);
GO

-- Helper to extend the partition function with one more future month boundary.
-- Usage: EXEC raw.usp_add_month_partition @year = 2027, @month = 1;
CREATE OR ALTER PROCEDURE raw.usp_add_month_partition
    @year  INT,
    @month INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @boundary DATE = DATEFROMPARTS(@year, @month, 1);

    ALTER PARTITION SCHEME ps_oef_monthly NEXT USED [PRIMARY];
    ALTER PARTITION FUNCTION pf_oef_monthly() SPLIT RANGE (@boundary);
END;
GO
