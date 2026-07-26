-- Report 13: Hoa hong quan ly cho Truong phong / Giam doc chi nhanh, tinh tren tong doanh so
-- (fee_revenue) cua ca phong ban / chi nhanh trong thang, theo ty le trong
-- management_commission_schedule. Bo sung theo yeu cau: HR co cap Truong phong/Giam doc de nhan
-- hoa hong quan ly va danh gia phong ban.
with dept_revenue as (
    select
        year(t.trade_date)  as trade_year,
        month(t.trade_date) as trade_month,
        b.department_id,
        sum(t.fee_amount)   as department_fee_revenue
    from {{ ref('int_all_trades') }} t
    join {{ ref('dim_broker') }} b on b.broker_code = t.broker_code
    group by 1, 2, 3
),

branch_revenue as (
    select
        year(t.trade_date)  as trade_year,
        month(t.trade_date) as trade_month,
        b.branch_id,
        sum(t.fee_amount)   as branch_fee_revenue
    from {{ ref('int_all_trades') }} t
    join {{ ref('dim_broker') }} b on b.broker_code = t.broker_code
    group by 1, 2, 3
),

head_of_department as (
    select
        dr.trade_year,
        dr.trade_month,
        'HEAD_OF_DEPARTMENT'  as management_level,
        d.department_id       as org_unit_id,
        d.department_name     as org_unit_name,
        d.head_employee_code  as employee_code,
        dr.department_fee_revenue as subordinate_revenue,
        mc.commission_rate,
        dr.department_fee_revenue * mc.commission_rate as override_commission_amount
    from dept_revenue dr
    join {{ ref('dim_department') }} d on d.department_id = dr.department_id
    left join {{ ref('dim_management_commission_schedule') }} mc
        on mc.management_level = 'HEAD_OF_DEPARTMENT'
       and mc.is_current
    where d.head_employee_code is not null
),

branch_director as (
    select
        br.trade_year,
        br.trade_month,
        'BRANCH_DIRECTOR'   as management_level,
        b.branch_id         as org_unit_id,
        b.branch_name       as org_unit_name,
        b.director_employee_code as employee_code,
        br.branch_fee_revenue as subordinate_revenue,
        mc.commission_rate,
        br.branch_fee_revenue * mc.commission_rate as override_commission_amount
    from branch_revenue br
    join {{ ref('dim_branch') }} b on b.branch_id = br.branch_id
    left join {{ ref('dim_management_commission_schedule') }} mc
        on mc.management_level = 'BRANCH_DIRECTOR'
       and mc.is_current
    where b.director_employee_code is not null
)

all_levels as (
    select * from head_of_department
    union all
    select * from branch_director
)

-- Join HR (dim_employee) here, once, for both levels - so the report shows who actually gets paid
-- (full_name/position), not just the raw employee_code.
select
    al.trade_year,
    al.trade_month,
    al.management_level,
    al.org_unit_id,
    al.org_unit_name,
    al.employee_code,
    e.full_name        as employee_name,
    e.position         as employee_position,
    al.subordinate_revenue,
    al.commission_rate,
    al.override_commission_amount
from all_levels al
left join {{ ref('dim_employee') }} e on e.employee_code = al.employee_code
