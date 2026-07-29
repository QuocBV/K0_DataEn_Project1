-- Unified account dimension across the 3 product DBs. account_id is only unique WITHIN its
-- source product database (SSI_Equity.account_id=1 and SSI_Derivatives.account_id=1 are different
-- accounts) - every join against this model and the unioned fact_* snapshot tables must use the
-- composite key (product_type, account_id), never account_id alone.
select 'EQUITY' as product_type, account_id, account_no, customer_code, broker_code, open_date, is_active
from {{ source('silver', 'account') }}
where _source_db = 'equity'

union all

select 'DERIVATIVES' as product_type, account_id, account_no, customer_code, broker_code, open_date, is_active
from {{ source('silver', 'account') }}
where _source_db = 'derivatives'

union all

select 'OEF' as product_type, account_id, account_no, customer_code, broker_code, open_date, is_active
from {{ source('silver', 'account') }}
where _source_db = 'oef'
