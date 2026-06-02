# dbt-binning

Turn SQL binning rules into data.

## Seed

threshold

0
2
6
7

## Generate bins

```sql
-- models/amount_bins.sql
{{ config(materialized='view') }}

{{ generate_bins(ref('amount_thresholds')) }}
```

`amount_bins` is intentionally materialized as a view. Threshold tables are
usually small, and keeping generated ranges as a view makes changes easy to
inspect.

## Output

| bin_start | bin_end | label |
| --------- | ------- | ----- |
| 0         | 2       | 0-1   |
| 2         | 6       | 2-5   |
| 6         | 7       | 6     |
| 7         | null    | 7+    |

## Join from another model

Use the generated bins like a small dimension table:

```sql
-- models/orders_with_amount_bins.sql
select
    orders.order_id,
    orders.amount,
    amount_bins.label as amount_bin

from {{ ref('orders') }} as orders
left join {{ ref('amount_bins') }} as amount_bins
    on orders.amount >= amount_bins.bin_start
    and (
        orders.amount < amount_bins.bin_end
        or amount_bins.bin_end is null
    )
```

This replaces a repeated `case when amount ... then ... end` block with one
threshold seed, one generated bins model, and ordinary SQL joins wherever the
bin is needed.
