select
    security_id,
    symbol,
    security_name,
    exchange,
    sector,
    security_type,
    listing_date,
    is_active
from {{ source('silver', 'security') }}
