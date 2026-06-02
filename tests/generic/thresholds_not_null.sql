{% test thresholds_not_null(model) %}

select *
from {{ model }}
where threshold is null

{% endtest %}