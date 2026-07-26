select
    b.branch_id,
    b.branch_code,
    b.branch_name,
    b.address,
    b.director_employee_code,
    e.full_name as director_name,
    b.is_active
from {{ ref('stg_common__branch') }} b
left join {{ ref('stg_hr__employee') }} e
    on e.employee_code = b.director_employee_code
