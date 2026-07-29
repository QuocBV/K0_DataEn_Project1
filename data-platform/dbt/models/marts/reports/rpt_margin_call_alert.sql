-- Computed by Spark Commission Engine. See data-platform/spark/jobs/commission_engine.py
select * from {{ source('reporting', 'rpt_margin_call_alert') }}

