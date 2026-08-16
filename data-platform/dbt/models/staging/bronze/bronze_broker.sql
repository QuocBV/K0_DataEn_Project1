{{ config(materialized='table') }}

-- Bronze: broker raw Parquet -> Iceberg bronze
select
    broker_code,
    broker_name,
    broker_type,
    broker_subtype,
    department_id,
    employee_code,
    id_number,
    phone,
    email,
    start_date,
    end_date,
    is_active,
    source_system,
    source_updated_at,
    ingested_at
from {{ source('raw_common', 'broker') }}
