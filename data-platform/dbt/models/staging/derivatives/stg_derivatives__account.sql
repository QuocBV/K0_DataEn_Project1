select
    account_id,
    account_no,
    customer_code,
    broker_code,
    open_date,
    is_active
from {{ source('raw_derivatives', 'account') }}
