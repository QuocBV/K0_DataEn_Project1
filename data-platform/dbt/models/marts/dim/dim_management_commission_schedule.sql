select
    schedule_id,
    management_level,
    commission_rate,
    effective_from,
    effective_to,
    is_current
from {{ ref('stg_common__management_commission_schedule') }}
