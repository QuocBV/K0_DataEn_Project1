select
    price_date,
    security_id,
    close_price,
    reference_price,
    ceiling_price,
    floor_price,
    volume
from {{ source('raw_equity', 'daily_price') }}
