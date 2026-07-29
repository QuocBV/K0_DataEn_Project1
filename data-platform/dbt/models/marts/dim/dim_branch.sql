select
    b.branch_id,
    b.branch_code,
    b.branch_name,
    b.address,
    b.director_employee_code,
    e.full_name as director_name,
    b.is_active
from {{ source('silver', 'branch') }} b
left join {{ source('silver', 'employees') }} e
    on e.employee_code = b.director_employee_code
