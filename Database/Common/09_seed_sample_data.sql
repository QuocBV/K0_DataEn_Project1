USE SSI_Common;
GO

-- Optional minimal seed data for local development / ETL testing only. Not for any real environment.
-- NV0003 = Truong phong PB01, NV0004 = Giam doc chi nhanh CN01 (xem hr-api/main.py)
INSERT INTO raw.branch (branch_code, branch_name, director_employee_code) VALUES
    ('CN01', N'Chi nhanh Ha Noi',   'NV0004'),
    ('CN02', N'Chi nhanh TP.HCM',   NULL);

INSERT INTO raw.department (department_code, department_name, branch_id, department_type, head_employee_code) VALUES
    ('PB01', N'Phong Moi Gioi Ha Noi', 1, 'BROKERAGE', 'NV0003'),
    ('PB02', N'Phong Moi Gioi TP.HCM', 2, 'BROKERAGE', NULL);

-- id_number (CCCD) below matches hr-api/main.py's static examples 1:1 (same employee_code /
-- id_number pairs) so the small sample dataset demonstrates full end-to-end HR mapping - the
-- at-scale generator (10_seed_at_scale.sql) generates random CCCD that will NOT match hr-api's
-- static mock (a real HR system would have the full roster; the mock only covers this example set).
INSERT INTO raw.broker (broker_code, broker_name, broker_type, broker_subtype, department_id, employee_code, id_number, phone, email, start_date) VALUES
    ('MG001',  N'Nguyen Van A', 'BROKER',       'STANDARD',            1, 'NV0001', '001099000001', '0900000001', 'a.nguyen@ssi.com.vn', '2021-03-01'),
    ('MG002',  N'Tran Thi B',   'BROKER',       'SENIOR',              2, 'NV0002', '079099000002', '0900000002', 'b.tran@ssi.com.vn',   '2019-07-15'),
    ('CTV001', N'Le Van C',     'COLLABORATOR', 'REFERRAL_INDIVIDUAL', 1, NULL,     '001099000099', '0900000003', 'c.le@example.com',    '2023-01-10');

INSERT INTO raw.customer (customer_code, customer_name, customer_type, residency, open_date) VALUES
    ('KH00001', N'Pham Thi D',      'INDIVIDUAL',   'DOMESTIC', '2022-05-01'),
    ('KH00002', N'Cong ty TNHH E',  'ORGANIZATION', 'DOMESTIC', '2022-08-15');

EXEC raw.usp_assign_broker @customer_code = 'KH00001', @broker_code = 'MG001', @effective_date = '2022-05-01';
EXEC raw.usp_assign_broker @customer_code = 'KH00002', @broker_code = 'MG002', @effective_date = '2022-08-15';

EXEC raw.usp_set_customer_risk_profile @customer_code = 'KH00001', @investor_classification = 'NON_PROFESSIONAL', @risk_level = 'MEDIUM', @effective_date = '2022-05-01';
EXEC raw.usp_set_customer_risk_profile @customer_code = 'KH00002', @investor_classification = 'PROFESSIONAL',     @risk_level = 'HIGH',   @effective_date = '2022-08-15';

EXEC raw.usp_set_customer_segment @customer_code = 'KH00001', @segment = 'RETAIL', @effective_date = '2022-05-01';
EXEC raw.usp_set_customer_segment @customer_code = 'KH00002', @segment = 'VIP',    @effective_date = '2022-08-15';

INSERT INTO raw.customer_acquisition (customer_code, acquisition_channel, referral_broker_code, acquisition_date) VALUES
    ('KH00001', 'BRANCH',   'MG001', '2022-05-01'),
    ('KH00002', 'REFERRAL', 'MG002', '2022-08-15');

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
