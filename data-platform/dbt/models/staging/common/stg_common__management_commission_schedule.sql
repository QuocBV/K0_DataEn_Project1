select
    schedule_id,
    management_level,
    commission_rate,
    effective_from,
    effective_to,
    is_current
from {{ source('raw_common', 'management_commission_schedule') }}
