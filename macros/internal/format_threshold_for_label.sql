{% macro format_threshold_for_label(column_name) %}

case
    when {{ column_name }} = floor({{ column_name }})
        then cast(cast({{ column_name }} as bigint) as {{ dbt.type_string() }})
    else cast({{ column_name }} as {{ dbt.type_string() }})
end

{% endmacro %}