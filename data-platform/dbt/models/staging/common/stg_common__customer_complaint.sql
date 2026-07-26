select
    complaint_id,
    customer_code,
    broker_code,
    complaint_date,
    channel,
    category,
    status,
    resolution_date,
    ingested_at
from {{ source('raw_common', 'customer_complaint') }}
