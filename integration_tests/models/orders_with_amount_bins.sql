-- Example migration target for a CASE WHEN amount banding model.

{{ config(materialized='table') }}

select
    orders.order_id,
    orders.amount,
    amount_bins.bin_label as amount_bin

from {{ ref('orders') }} orders
{{ dbt_binning.join_bins(
    value_column='orders.amount',
    bins=ref('amount_bins'),
    bins_alias='amount_bins'
) }}
