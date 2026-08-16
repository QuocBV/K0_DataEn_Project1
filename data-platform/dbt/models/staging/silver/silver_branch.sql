{{ config(materialized='table') }}

-- Silver: branch bronze -> clean/dedup -> Iceberg silver
select
    branch_id,
    branch_code,
    branch_name,
    address,
    director_employee_code,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ ref('bronze_branch') }}
