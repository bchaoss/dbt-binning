{% macro bin_join(value, bins, bins_alias='bins') %}

left join {{ bins }} as {{ bins_alias }}
    on {{ value }} >= {{ bins_alias }}.bin_start
    and (
        {{ value }} < {{ bins_alias }}.bin_end
        or {{ bins_alias }}.bin_end is null
    )

{% endmacro %}
