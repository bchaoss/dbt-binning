{% test generated_ranges_valid(model) %}

select *
from {{ model }}
where
    bin_end is not null
    and bin_end <= bin_start

{% endtest %}
