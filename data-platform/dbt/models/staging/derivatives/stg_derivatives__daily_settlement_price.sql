select
    price_date,
    contract_id,
    settlement_price,
    open_interest,
    volume
from {{ source('raw_derivatives', 'daily_settlement_price') }}
