select
    id_number,           -- CCCD - universal key, present for both EMPLOYEE (MG/quan ly) and COLLABORATOR (CTV)
    employee_code,        -- only set when person_type = EMPLOYEE
    full_name,
    person_type,          -- EMPLOYEE / COLLABORATOR
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
from {{ source('raw_hr', 'employees') }}
