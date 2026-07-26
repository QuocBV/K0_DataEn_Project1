-- HR/partner join is done via id_number (CCCD), NOT employee_code: employee_code only exists for
-- broker_type='BROKER' (SSI employees), so joining on it would leave every COLLABORATOR (CTV) row
-- unmatched to HR/partner data. id_number is the one key both BROKER and COLLABORATOR always have
-- (see Database/Common/03_broker.sql's header comment and hr-api/main.py's Person model).
select
    br.broker_code,
    br.broker_name,
    br.broker_type,
    br.broker_subtype,
    br.department_id,
    dep.department_name,
    dep.branch_id,
    bra.branch_name,
    br.employee_code,
    br.id_number,
    e.position_level,
    e.manager_employee_code,
    br.phone,
    br.email,
    br.start_date,
    br.end_date,
    br.is_active
from {{ ref('stg_common__broker') }} br
left join {{ ref('dim_department') }} dep on dep.department_id = br.department_id
left join {{ ref('dim_branch') }} bra on bra.branch_id = dep.branch_id
left join {{ ref('stg_hr__employee') }} e on e.id_number = br.id_number
