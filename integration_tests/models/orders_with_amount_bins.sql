-- Example migration target for a CASE WHEN amount banding model.

{{ config(materialized='table') }}

with orders as (

    select *
    from {{ ref('orders') }}

),

amount_bins as (

    select *
    from {{ ref('amount_bins') }}

)

select
    orders.order_id,
    orders.amount,
    amount_bins.label as amount_bin

from orders
{{ dbt_binning.bin_join(
    value='orders.amount',
    bins='amount_bins',
    bins_alias='amount_bins'
) }}
