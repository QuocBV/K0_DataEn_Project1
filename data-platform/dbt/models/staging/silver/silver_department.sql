{{ config(materialized='table') }}

-- Silver: department bronze -> clean/dedup -> Iceberg silver
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
from {{ ref('bronze_department') }}
