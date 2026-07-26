select
    fee_schedule_id,
    product_type,
    broker_tier,
    fee_rate,
    commission_rate,
    effective_from,
    effective_to,
    is_current
from {{ source('raw_common', 'fee_schedule') }}
