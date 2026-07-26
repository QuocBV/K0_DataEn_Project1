-- SCD Type 2 pass-through: which Broker/Collaborator cared for a customer, valid_from/valid_to.
-- Kept as its own mart model (rather than reports reaching into staging directly) so every
-- point-in-time broker-attribution report joins the same, consistently named object.
select
    history_id,
    customer_code,
    broker_code,
    valid_from,
    valid_to,
    is_current
from {{ ref('stg_common__customer_broker_history') }}
