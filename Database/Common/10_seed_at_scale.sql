USE SSI_Common;
GO

-- At-scale synthetic seed data for load/report testing: 5 chi nhanh, 15 phong ban, 300 Moi gioi/CTV,
-- 1000 Khach hang - voi phan bo LECH (khong dong deu) giong thuc te: mot so it Moi gioi quan ly rat
-- nhieu khach (top performer), da so chi quan ly vai chuc khach (long-tail). Day la ban thay the
-- cho 09_seed_sample_data.sql - CHI CHAY 1 TRONG 2 (ca hai deu tao branch/department/broker/customer
-- tu dau, chay ca hai se bi trung du lieu).
--
-- Keys: broker.broker_code va customer.customer_code la PRIMARY KEY (string, khong dung surrogate
-- int) - xem ghi chu trong 03_broker.sql / 04_customer.sql.
SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- 1. Branch & Department
-------------------------------------------------------------------------------
INSERT INTO raw.branch (branch_code, branch_name, director_employee_code) VALUES
    ('CN01', N'Chi nhanh Ha Noi',    'NV9001'),
    ('CN02', N'Chi nhanh TP.HCM',    'NV9002'),
    ('CN03', N'Chi nhanh Da Nang',   'NV9003'),
    ('CN04', N'Chi nhanh Hai Phong', NULL),
    ('CN05', N'Chi nhanh Can Tho',   NULL);

;WITH nums AS (
    SELECT TOP (15) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO raw.department (department_code, department_name, branch_id, department_type, head_employee_code)
SELECT
    'PB' + RIGHT('000' + CAST(n AS VARCHAR(3)), 3),
    N'Phong Moi Gioi ' + CAST(n AS NVARCHAR(3)),
    ((n - 1) % 5) + 1,
    'BROKERAGE',
    CASE WHEN n % 3 = 0 THEN 'NV9' + RIGHT('00' + CAST(n AS VARCHAR(2)), 2) ELSE NULL END
FROM nums;

-------------------------------------------------------------------------------
-- 2. Broker / Collaborator (300): ~70% BROKER (co employee_code), ~30% COLLABORATOR, moi nhom lai
--    chia them theo broker_subtype (xem 03_broker.sql).
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#first_names') IS NOT NULL DROP TABLE #first_names;
IF OBJECT_ID('tempdb..#last_names') IS NOT NULL DROP TABLE #last_names;

CREATE TABLE #first_names (name NVARCHAR(50));
INSERT INTO #first_names (name) VALUES
    (N'Van An'), (N'Thi Bich'), (N'Minh Chau'), (N'Quoc Dung'), (N'Thi Ha'),
    (N'Hoang Khoa'), (N'Thi Lan'), (N'Van Minh'), (N'Thi Ngoc'), (N'Duc Phong'),
    (N'Thi Quyen'), (N'Van Son'), (N'Thi Thao'), (N'Anh Tuan'), (N'Thi Van'),
    (N'Xuan Y'), (N'Gia Bao'), (N'Ngoc Diep'), (N'Huu Loc'), (N'Kim Ngan');

CREATE TABLE #last_names (name NVARCHAR(50));
INSERT INTO #last_names (name) VALUES
    (N'Nguyen'), (N'Tran'), (N'Le'), (N'Pham'), (N'Hoang'),
    (N'Huynh'), (N'Phan'), (N'Vu'), (N'Vo'), (N'Dang'),
    (N'Bui'), (N'Do'), (N'Ho'), (N'Ngo'), (N'Duong');

;WITH nums AS (
    SELECT TOP (300) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
typed AS (
    SELECT n,
           CASE WHEN n % 10 < 7 THEN 'BROKER' ELSE 'COLLABORATOR' END AS broker_type,
           ABS(CHECKSUM(NEWID())) % 100 AS roll
    FROM nums
)
INSERT INTO raw.broker (broker_code, broker_name, broker_type, broker_subtype, department_id, employee_code, id_number, phone, email, start_date)
SELECT
    'MG' + RIGHT('0000' + CAST(n AS VARCHAR(4)), 4),
    ln.name + N' ' + fn.name,
    broker_type,
    CASE
        WHEN broker_type = 'BROKER' AND roll < 70 THEN 'STANDARD'
        WHEN broker_type = 'BROKER' AND roll < 90 THEN 'SENIOR'
        WHEN broker_type = 'BROKER' AND roll < 97 THEN 'TEAM_LEAD'
        WHEN broker_type = 'BROKER'               THEN 'RM_VIP'
        WHEN broker_type = 'COLLABORATOR' AND roll < 60 THEN 'REFERRAL_INDIVIDUAL'
        WHEN broker_type = 'COLLABORATOR' AND roll < 90 THEN 'REFERRAL_AFFILIATE'
        ELSE 'REFERRAL_INSTITUTIONAL'
    END,
    ((n - 1) % 15) + 1,
    CASE WHEN broker_type = 'BROKER' THEN 'NV' + RIGHT('0000' + CAST(2000 + n AS VARCHAR(4)), 4) ELSE NULL END,
    -- CCCD gia lap, sinh theo n (khong dung thuan random) de dam bao duy nhat tuyet doi qua
    -- uq_broker_id_number - trung 12 chu so voi random tren 300 dong la rui ro khong dang, nhung
    -- van tranh de an toan tuyet doi.
    '0900' + RIGHT('00000000' + CAST(n AS VARCHAR(8)), 8),
    '09' + RIGHT('0000000' + CAST(ABS(CHECKSUM(NEWID())) % 10000000 AS VARCHAR(7)), 7),
    'broker' + CAST(n AS VARCHAR(4)) + '@ssi.com.vn',
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 2000), '2027-01-01')
FROM typed
CROSS APPLY (SELECT TOP 1 name FROM #first_names ORDER BY (ABS(CHECKSUM(NEWID())) + n) ) fn
CROSS APPLY (SELECT TOP 1 name FROM #last_names  ORDER BY (ABS(CHECKSUM(NEWID())) + n) ) ln;

-- Safety net: broker_subtype='RM_VIP' is assigned probabilistically above (~3% of ~210 BROKER
-- rows), so there's a small but real chance (~0.2%) that zero brokers land on RM_VIP out of 300.
-- Section 4 requires at least one RM_VIP to care for the PROPRIETARY accounts - if none exists,
-- promote the first BROKER-type row deterministically rather than let that INSERT fail on a NULL
-- broker_code.
IF NOT EXISTS (SELECT 1 FROM raw.broker WHERE broker_subtype = 'RM_VIP')
BEGIN
    UPDATE raw.broker
    SET broker_subtype = 'RM_VIP'
    WHERE broker_code = (SELECT TOP 1 broker_code FROM raw.broker WHERE broker_type = 'BROKER' ORDER BY broker_code);
END;

-------------------------------------------------------------------------------
-- 3. Customer (1000): 899 INDIVIDUAL + 99 ORGANIZATION + 2 PROPRIETARY (tu doanh - tai khoan cua
--    chinh cong ty), moi khach ~8% la NDT nuoc ngoai (residency = FOREIGN); tu doanh luon DOMESTIC.
-------------------------------------------------------------------------------
;WITH nums AS (
    SELECT TOP (998) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO raw.customer (customer_code, customer_name, customer_type, residency, phone, email, open_date)
SELECT
    'KH' + RIGHT('00000' + CAST(n AS VARCHAR(5)), 5),
    CASE WHEN n % 10 = 0
         THEN N'Cong ty TNHH ' + ln.name + N' ' + fn.name
         ELSE ln.name + N' ' + fn.name
    END,
    CASE WHEN n % 10 = 0 THEN 'ORGANIZATION' ELSE 'INDIVIDUAL' END,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 8 THEN 'FOREIGN' ELSE 'DOMESTIC' END,
    '09' + RIGHT('0000000' + CAST(ABS(CHECKSUM(NEWID())) % 10000000 AS VARCHAR(7)), 7),
    'customer' + CAST(n AS VARCHAR(5)) + '@example.com',
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 1460), '2027-01-01')  -- opened within the last ~4 years
FROM nums n
CROSS APPLY (SELECT TOP 1 name FROM #first_names ORDER BY (ABS(CHECKSUM(NEWID())) + n) ) fn
CROSS APPLY (SELECT TOP 1 name FROM #last_names  ORDER BY (ABS(CHECKSUM(NEWID())) + n) ) ln;

INSERT INTO raw.customer (customer_code, customer_name, customer_type, residency, open_date) VALUES
    ('TD0001', N'SSI - Tai khoan tu doanh 1', 'PROPRIETARY', 'DOMESTIC', '2015-01-01'),
    ('TD0002', N'SSI - Tai khoan tu doanh 2', 'PROPRIETARY', 'DOMESTIC', '2015-01-01');

-------------------------------------------------------------------------------
-- 4. Customer <-> Broker assignment (weighted random: a few brokers get large books).
--    Proprietary accounts are cared for by a dedicated senior broker profile, not the general pool.
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#broker_ranges') IS NOT NULL DROP TABLE #broker_ranges;

;WITH broker_weight AS (
    SELECT broker_code, 1 + (ABS(CHECKSUM(NEWID())) % 15) AS weight  -- 1-15, long-tail via random spread
    FROM raw.broker
    WHERE broker_subtype <> 'RM_VIP'  -- RM_VIP handled separately for VIP/proprietary below
),
broker_ranges AS (
    SELECT
        broker_code,
        weight,
        SUM(weight) OVER (ORDER BY broker_code ROWS UNBOUNDED PRECEDING) AS range_end,
        SUM(weight) OVER (ORDER BY broker_code ROWS UNBOUNDED PRECEDING) - weight + 1 AS range_start
    FROM broker_weight
)
SELECT * INTO #broker_ranges FROM broker_ranges;

DECLARE @broker_total_weight INT = (SELECT MAX(range_end) FROM #broker_ranges);

;WITH draws AS (
    SELECT
        customer_code,
        1 + (ABS(CHECKSUM(NEWID())) % @broker_total_weight) AS draw,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 1000), '2027-01-01') AS assigned_from
    FROM raw.customer
    WHERE customer_type <> 'PROPRIETARY'
)
INSERT INTO raw.customer_broker_history (customer_code, broker_code, valid_from, is_current)
SELECT d.customer_code, br.broker_code, d.assigned_from, 1
FROM draws d
JOIN #broker_ranges br ON d.draw BETWEEN br.range_start AND br.range_end;

-- Proprietary accounts: assigned to the first available RM_VIP broker
INSERT INTO raw.customer_broker_history (customer_code, broker_code, valid_from, is_current)
SELECT c.customer_code, (SELECT TOP 1 broker_code FROM raw.broker WHERE broker_subtype = 'RM_VIP' ORDER BY broker_code), c.open_date, 1
FROM raw.customer c
WHERE c.customer_type = 'PROPRIETARY';

-------------------------------------------------------------------------------
-- 5. Customer risk profile (LOW 50% / MEDIUM 35% / HIGH 15%), investor classification
-------------------------------------------------------------------------------
;WITH r AS (
    SELECT customer_code, ABS(CHECKSUM(NEWID())) % 100 AS roll, open_date
    FROM raw.customer
)
INSERT INTO raw.customer_risk_profile (customer_code, investor_classification, risk_level, valid_from)
SELECT
    customer_code,
    CASE WHEN roll < 5 THEN 'PROFESSIONAL' ELSE 'NON_PROFESSIONAL' END,
    CASE WHEN roll < 50 THEN 'LOW' WHEN roll < 85 THEN 'MEDIUM' ELSE 'HIGH' END,
    open_date
FROM r;

-------------------------------------------------------------------------------
-- 6. Customer segment (RETAIL 80% / PRIORITY 15% / VIP 5%) - proprietary accounts are always VIP
-------------------------------------------------------------------------------
;WITH r AS (
    SELECT customer_code, customer_type, ABS(CHECKSUM(NEWID())) % 100 AS roll, open_date
    FROM raw.customer
)
INSERT INTO raw.customer_segment_history (customer_code, segment, valid_from)
SELECT
    customer_code,
    CASE
        WHEN customer_type = 'PROPRIETARY' THEN 'VIP'
        WHEN roll < 80 THEN 'RETAIL' WHEN roll < 95 THEN 'PRIORITY' ELSE 'VIP'
    END,
    open_date
FROM r;

-------------------------------------------------------------------------------
-- 7. Customer acquisition (BRANCH 40% / ONLINE 35% / REFERRAL 20% / EVENT 5%)
-------------------------------------------------------------------------------
;WITH r AS (
    SELECT customer_code, ABS(CHECKSUM(NEWID())) % 100 AS roll, open_date
    FROM raw.customer
),
channel AS (
    SELECT
        customer_code, open_date,
        CASE WHEN roll < 40 THEN 'BRANCH' WHEN roll < 75 THEN 'ONLINE'
             WHEN roll < 95 THEN 'REFERRAL' ELSE 'EVENT' END AS acquisition_channel
    FROM r
)
INSERT INTO raw.customer_acquisition (customer_code, acquisition_channel, referral_broker_code, acquisition_date)
SELECT
    ch.customer_code,
    ch.acquisition_channel,
    CASE WHEN ch.acquisition_channel = 'REFERRAL' THEN cbh.broker_code ELSE NULL END,
    ch.open_date
FROM channel ch
LEFT JOIN raw.customer_broker_history cbh
    ON cbh.customer_code = ch.customer_code AND cbh.is_current = 1;

-------------------------------------------------------------------------------
-- 8. Reference data (fee schedule, management commission schedule, market index) - these are
--    small, non-scaled tables but 10_seed_at_scale.sql is meant to be a full standalone
--    alternative to 09_seed_sample_data.sql, so it must seed them too (otherwise anyone who runs
--    10 instead of 09 ends up with an empty fee_schedule and broken commission-rate lookups).
-------------------------------------------------------------------------------
INSERT INTO raw.fee_schedule (product_type, broker_tier, fee_rate, commission_rate, effective_from) VALUES
    ('EQUITY',      NULL, 0.0015, 0.30, '2022-01-01'),
    ('DERIVATIVES', NULL, 0.0002, 0.25, '2022-01-01'),
    ('OEF',         NULL, 0.0000, 0.50, '2022-01-01');

INSERT INTO raw.management_commission_schedule (management_level, commission_rate, effective_from) VALUES
    ('HEAD_OF_DEPARTMENT', 0.05, '2022-01-01'),
    ('BRANCH_DIRECTOR',    0.03, '2022-01-01');

INSERT INTO raw.market_index_price (price_date, index_code, close_value, change_percent) VALUES
    ('2026-07-17', 'VNINDEX', 1280.50, 0.35),
    ('2026-07-17', 'VN30',    1330.20, 0.42);

DROP TABLE #first_names;
DROP TABLE #last_names;
DROP TABLE #broker_ranges;
