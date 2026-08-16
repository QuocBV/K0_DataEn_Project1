USE SSI_Common;
GO

-- View over raw.broker + org data, shaped like hr-api's Person model so dbt dim_employee /
-- dim_broker / dim_department joins keep working end-to-end after removing the Airbyte->S3->
-- Spark->Silver path. id_number is the universal join key (present for both BROKER and
-- COLLABORATOR rows).
CREATE VIEW raw.employees AS
SELECT
    b.id_number,
    b.employee_code,
    b.broker_name                                AS full_name,
    CASE WHEN b.broker_type = 'COLLABORATOR'
         THEN 'COLLABORATOR'
         ELSE 'EMPLOYEE'
    END                                          AS person_type,
    br.branch_code,
    br.branch_name,
    d.department_code,
    d.department_name,
    b.broker_name                                AS [position],
    b.broker_subtype                             AS position_code,
    CASE b.broker_type
        WHEN 'COLLABORATOR' THEN 'COLLABORATOR'
        ELSE 'BROKER'
    END                                          AS position_level,
    NULL                                         AS manager_employee_code,
    b.start_date,
    b.end_date,
    CASE WHEN b.is_active = 1 THEN 'ACTIVE' ELSE 'INACTIVE' END AS status
FROM raw.broker b
LEFT JOIN raw.department d  ON d.department_id = b.department_id
LEFT JOIN raw.branch br     ON br.branch_id   = d.branch_id;
GO