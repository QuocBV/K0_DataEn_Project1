select
    contract_id,
    contract_code,
    underlying_symbol,
    contract_type,
    multiplier,
    listing_date,
    maturity_date,
    is_active
from {{ ref('stg_derivatives__derivative_contract') }}
