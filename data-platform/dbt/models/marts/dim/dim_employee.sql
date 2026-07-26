-- Standalone HR/partner dimension (Truong phong / Giam doc / Moi gioi / CTV), used by
-- department/branch evaluation and management-commission reports. Sourced from the HR API (see
-- hr-api/) - swapping the real HR/partner system in behind that API requires no change here.
-- id_number (CCCD) is the grain key - it covers both EMPLOYEE and COLLABORATOR rows, unlike
-- employee_code which COLLABORATOR (CTV) rows don't have.
select
    id_number,
    employee_code,
    full_name,
    person_type,
    branch_code,
    branch_name,
    department_code,
    department_name,
    position,
    position_code,
    position_level,
    manager_employee_code,
    start_date,
    end_date,
    status
from {{ ref('stg_hr__employee') }}
