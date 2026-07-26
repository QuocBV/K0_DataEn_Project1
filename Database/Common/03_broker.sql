USE SSI_Common;
GO

-- Broker (Moi gioi) / Collaborator (Cong tac vien), assigned to one Department.
-- Keyed by broker_code (string, e.g. 'MG0001') instead of a surrogate int id: broker_code is the
-- real-world business identifier already used by the source CRM, and since customer_code/
-- broker_code are the only link the 3 product databases have back to SSI_Common (SQL Server does
-- not support cross-database FOREIGN KEY), a stable, human-readable natural key is more robust
-- than an auto-increment integer that could differ across environments/reloads.
--
-- HR/doi tac data (ho ten day du, chuc danh, phong ban theo ma, ngay bat dau/ket thuc,...) KHONG
-- mirror o day - lay qua HR API (xem hr-api/), tra cuu theo id_number (CCCD) hoac employee_code.
-- id_number la khoa mapping DUY NHAT dung chung cho ca BROKER (nhan vien chinh thuc) va
-- COLLABORATOR (CTV ben ngoai) - employee_code chi co o BROKER, con id_number (CCCD) thi ai cung
-- co, nen he thong quan ly doi tac/HR ben ngoai dung id_number de khop ca 2 nhom.
CREATE TABLE raw.broker (
    broker_code         VARCHAR(20)   NOT NULL,
    broker_name         NVARCHAR(200) NOT NULL,
    broker_type         VARCHAR(15)   NOT NULL,
    -- broker_subtype: phan loai chi tiet trong tung nhom.
    --   BROKER:       STANDARD (chuyen vien MG) / SENIOR (MG cao cap) / TEAM_LEAD (truong nhom)
    --                 / RM_VIP (chuyen vien quan he KH VIP / wealth manager)
    --   COLLABORATOR: REFERRAL_INDIVIDUAL (CTV ca nhan gioi thieu) / REFERRAL_AFFILIATE
    --                 (CTV lien ket - kenh online/KOL) / REFERRAL_INSTITUTIONAL (doi tac to chuc)
    broker_subtype      VARCHAR(25)   NULL,
    department_id       INT           NOT NULL,
    employee_code       VARCHAR(20)   NULL,   -- HR employee code; required when broker_type = 'BROKER'
    -- id_number: so CCCD - khoa mapping sang HR/doi tac registry (hr-api), ap dung cho ca MG va CTV.
    -- Du lieu nhay cam (dinh danh ca nhan) - ap dung ma hoa/masking theo chinh sach DLP giong
    -- raw.customer.id_number (xem 04_customer.sql).
    id_number           VARCHAR(20)   NULL,
    phone               VARCHAR(20)   NULL,
    email               NVARCHAR(200) NULL,
    start_date          DATE          NULL,
    end_date            DATE          NULL,
    is_active           BIT           NOT NULL CONSTRAINT df_broker_is_active DEFAULT (1),
    source_system       VARCHAR(50)   NOT NULL CONSTRAINT df_broker_source_system DEFAULT ('CRM'),
    source_updated_at   DATETIME2(3)  NULL,
    ingested_at         DATETIME2(3)  NOT NULL CONSTRAINT df_broker_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_broker PRIMARY KEY CLUSTERED (broker_code),
    CONSTRAINT fk_broker_department FOREIGN KEY (department_id) REFERENCES raw.department(department_id),
    CONSTRAINT chk_broker_type CHECK (broker_type IN ('BROKER', 'COLLABORATOR')),
    -- employee_code is mandatory for BROKER (employee), optional/NULL for external COLLABORATOR
    CONSTRAINT chk_employee_code_for_broker CHECK (broker_type <> 'BROKER' OR employee_code IS NOT NULL),
    CONSTRAINT chk_broker_subtype CHECK (
        (broker_type = 'BROKER' AND broker_subtype IN ('STANDARD', 'SENIOR', 'TEAM_LEAD', 'RM_VIP'))
        OR (broker_type = 'COLLABORATOR' AND broker_subtype IN ('REFERRAL_INDIVIDUAL', 'REFERRAL_AFFILIATE', 'REFERRAL_INSTITUTIONAL'))
    )
);
GO

CREATE INDEX idx_broker_department ON raw.broker(department_id);
GO

-- Filtered (not a plain UNIQUE constraint): SQL Server allows only ONE NULL under a plain UNIQUE
-- constraint, which would break the moment a 2nd broker is missing id_number. A filtered index
-- enforces uniqueness only among the rows that actually have a CCCD on file.
CREATE UNIQUE INDEX uq_broker_id_number ON raw.broker(id_number) WHERE id_number IS NOT NULL;
GO
