select
    d.department_id,
    d.department_code,
    d.department_name,
    d.branch_id,
    d.department_type,
    d.head_employee_code,
    e.full_name as head_name,
    d.is_active
from {{ source('silver', 'department') }} d
left join {{ source('silver', 'employees') }} e
    on e.employee_code = d.head_employee_code
