select
    history_id,
    customer_code,
    broker_code,
    valid_from,
    valid_to,
    is_current,
    source_system,
    ingested_at
from {{ source('raw_common', 'customer_broker_history') }}
