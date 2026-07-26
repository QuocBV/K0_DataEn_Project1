select
    fund_id,
    fund_code,
    fund_name,
    fund_type,
    fund_manager,
    inception_date,
    is_active
from {{ ref('stg_oef__fund') }}
