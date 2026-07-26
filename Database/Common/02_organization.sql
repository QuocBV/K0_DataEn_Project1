USE SSI_Common;
GO

-- Branch (Chi nhanh)
CREATE TABLE raw.branch (
    branch_id           INT           IDENTITY(1,1) NOT NULL,
    branch_code         VARCHAR(20)   NOT NULL,
    branch_name         NVARCHAR(200) NOT NULL,
    address             NVARCHAR(500) NULL,
    director_employee_code VARCHAR(20) NULL,  -- HR employee code of the Giam doc chi nhanh; used to compute management-override commission on total branch revenue. Fetched via HR API, not a local FK.
    is_active           BIT           NOT NULL CONSTRAINT df_branch_is_active DEFAULT (1),
    source_system       VARCHAR(50)   NOT NULL CONSTRAINT df_branch_source_system DEFAULT ('ORG'),
    source_updated_at   DATETIME2(3)  NULL,
    ingested_at         DATETIME2(3)  NOT NULL CONSTRAINT df_branch_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_branch PRIMARY KEY CLUSTERED (branch_id),
    CONSTRAINT uq_branch_code UNIQUE (branch_code)
);
GO

-- Department (Phong ban), belongs to one Branch
CREATE TABLE raw.department (
    department_id       INT           IDENTITY(1,1) NOT NULL,
    department_code     VARCHAR(20)   NOT NULL,
    department_name     NVARCHAR(200) NOT NULL,
    branch_id           INT           NOT NULL,
    department_type     VARCHAR(30)   NULL,
    head_employee_code  VARCHAR(20)   NULL,  -- HR employee code of the Truong phong; used to compute management-override commission on total department revenue. Fetched via HR API, not a local FK.
    is_active           BIT           NOT NULL CONSTRAINT df_department_is_active DEFAULT (1),
    source_system       VARCHAR(50)   NOT NULL CONSTRAINT df_department_source_system DEFAULT ('ORG'),
    source_updated_at   DATETIME2(3)  NULL,
    ingested_at         DATETIME2(3)  NOT NULL CONSTRAINT df_department_ingested_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_department PRIMARY KEY CLUSTERED (department_id),
    CONSTRAINT uq_department_code UNIQUE (department_code),
    CONSTRAINT fk_department_branch FOREIGN KEY (branch_id) REFERENCES raw.branch(branch_id)
);
GO

CREATE INDEX idx_department_branch ON raw.department(branch_id);
GO
