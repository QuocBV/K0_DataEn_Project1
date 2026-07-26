-- Shared calendar dimension so every fact table (3 trade facts + daily snapshots) rolls up
-- consistently by week/month/quarter without repeating date-part logic in every report.
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2031-01-01' as date)"
    ) }}
)

select
    date_day                              as date_key,
    year(date_day)                        as year,
    quarter(date_day)                     as quarter,
    month(date_day)                       as month,
    monthname(date_day)                   as month_name,
    weekofyear(date_day)                  as week_of_year,
    dayofweek(date_day)                   as day_of_week,
    dayname(date_day)                     as day_name,
    case when dayofweek(date_day) in (0, 6) then true else false end as is_weekend
from spine
