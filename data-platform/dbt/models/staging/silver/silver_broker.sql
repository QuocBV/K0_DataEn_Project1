{{ config(materialized='table') }}

-- Silver: broker bronze -> clean/dedup -> Iceberg silver
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
    ingested_at,
    upper(trim(broker_code)) as broker_code,
    trim(broker_name) as broker_name,
    upper(trim(broker_type)) as broker_type,
    upper(trim(broker_subtype)) as broker_subtype
from {{ ref('bronze_broker') }}
