{% macro join_bins(value_column, bins, bins_alias='bins') %}

left join {{ bins }} as {{ bins_alias }}
    on (
        {{ bins_alias }}.bin_start is null
        and {{ value_column }} < {{ bins_alias }}.bin_end
    )
    or (
        {{ bins_alias }}.bin_start is not null
        and {{ value_column }} >= {{ bins_alias }}.bin_start
        and (
            {{ value_column }} < {{ bins_alias }}.bin_end
            or {{ bins_alias }}.bin_end is null
        )
    )

{% endmacro %}
