select
    schedule_id,
    management_level,
    commission_rate,
    effective_from,
    effective_to,
    is_current
from {{ source('silver', 'management_commission_schedule') }}
