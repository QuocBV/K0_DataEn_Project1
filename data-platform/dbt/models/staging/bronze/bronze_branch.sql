{{ config(materialized='table') }}

-- Bronze: branch raw Parquet -> Iceberg bronze
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
from {{ source('raw_common', 'branch') }}
