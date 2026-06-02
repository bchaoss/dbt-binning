{% macro generate_bins(threshold_relation) %}

with thresholds as (

    select distinct
        threshold
    from {{ threshold_relation }}

),

bins as (

    select
        threshold as bin_start,
        lead(threshold) over (
            order by threshold
        ) as bin_end

    from thresholds

)

select
    bin_start,
    bin_end,
    case
        when bin_end is null
        then cast(bin_start as {{ dbt.type_string() }}) || '+'

        when bin_end = bin_start + 1
        then cast(bin_start as {{ dbt.type_string() }})

        else
            cast(bin_start as {{ dbt.type_string() }})
            || '-'
            || cast(bin_end - 1 as {{ dbt.type_string() }})
    end as label

from bins

{% endmacro %}
