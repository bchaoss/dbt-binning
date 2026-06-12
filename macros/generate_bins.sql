{% macro generate_bins(threshold_relation) %}

{% do config.set('materialized', 'view') %}

with thresholds as (

    select distinct
        cast(threshold as {{ dbt.type_float() }}) as threshold
    from {{ threshold_relation }}

    where threshold is not null

),

bins as (

    select
        cast(null as {{ dbt.type_float() }}) as bin_start,
        min(threshold) as bin_end
    from thresholds

    union all

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
        when bin_start is null
        then '<' || {{ dbt_binning.format_threshold_for_label('bin_end') }}

        when bin_end is null
        then {{ dbt_binning.format_threshold_for_label('bin_start') }} || '+'

        else
            {{ dbt_binning.format_threshold_for_label('bin_start') }}
            || '-'
            || {{ dbt_binning.format_threshold_for_label('bin_end') }}
    end as label

from bins

{% endmacro %}
