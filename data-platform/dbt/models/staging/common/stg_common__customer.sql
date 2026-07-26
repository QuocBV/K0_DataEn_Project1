select
    customer_code,
    customer_name,
    customer_type,
    residency,
    -- id_number intentionally excluded from the analytics layer: sensitive personal identification
    -- data (Luat BVDLCN 91/2025/QH15) is not needed for trading/commission analytics and should not
    -- be replicated further than the operational source without a separate DLP-approved flow.
    phone,
    email,
    open_date,
    is_active,
    source_system,
    ingested_at
from {{ source('raw_common', 'customer') }}
