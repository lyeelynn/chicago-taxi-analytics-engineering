{% macro get_3_month_period(date_column, source_relation) %}

    {{ date_column }} >= (
        SELECT DATE(MAX({{ date_column }}) - INTERVAL 3 MONTH)
        FROM {{ source_relation }}
    )

{% endmacro %}