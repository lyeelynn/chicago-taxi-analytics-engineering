{% macro get_rolling_period(date_column, source_relation, months_back) %}

    SELECT
        DATE(MAX({{ date_column }})) - INTERVAL {{ months_back }} MONTH
            AS period_start_date,

        DATE(MAX({{ date_column }}))
            AS period_end_date

    FROM {{ source_relation }}

{% endmacro %}