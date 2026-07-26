select
    department_id,
    department_code,
    department_name,
    branch_id,
    department_type,
    head_employee_code,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_common', 'department') }}
