select
    customer_code,
    acquisition_channel,
    referral_broker_code,
    acquisition_date,
    campaign_code,
    source_system,
    ingested_at
from {{ source('raw_common', 'customer_acquisition') }}
