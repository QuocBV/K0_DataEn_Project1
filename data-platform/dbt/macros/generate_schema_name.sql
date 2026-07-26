{% macro generate_schema_name(custom_schema_name, node) -%}
    {#- Use the custom schema exactly as given (STG_COMMON, STG_EQUITY, MARTS, ...) instead of
        dbt's default "<target_schema>_<custom_schema>" concatenation, so models land in
        ANALYTICS.STG_EQUITY / ANALYTICS.MARTS rather than ANALYTICS.ANALYTICS_STG_EQUITY. #}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
