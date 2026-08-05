-- Unified account dimension. Since Phương án B, account data lives in a SINGLE source:
-- SSI_Common.raw.account. Each customer can have many accounts (1:N), and each account trades
-- exactly ONE product line (product_type is stored/CHECK-constrained on the unified table).
--
-- account_no is the GLOBAL unique business key; account_id is also global (surrogate).
-- No more per-product-DB identity collision, so no product_type/account_id composite needed
-- for uniqueness - but product_type is still kept for filtering/aggregation convenience.
select
    account_id,
    account_no,
    customer_code,
    broker_code,
    product_type,
    open_date,
    is_active,
    ingested_at
from {{ source('silver', 'account') }}