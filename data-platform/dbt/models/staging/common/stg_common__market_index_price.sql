select
    price_date,
    index_code,
    close_value,
    change_percent,
    volume
from {{ source('raw_common', 'market_index_price') }}
