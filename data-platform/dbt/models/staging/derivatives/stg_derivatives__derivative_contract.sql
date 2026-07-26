select
    contract_id,
    contract_code,
    underlying_symbol,
    contract_type,
    multiplier,
    listing_date,
    maturity_date,
    is_active
from {{ source('raw_derivatives', 'derivative_contract') }}
