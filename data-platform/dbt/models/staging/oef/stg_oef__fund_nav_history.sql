select
    nav_date,
    fund_id,
    nav_price,
    total_net_asset,
    outstanding_units
from {{ source('raw_oef', 'fund_nav_history') }}
