# dbt-binning
## Stop Maintaining CASE WHEN Binning Logic in SQL

One small pattern that made the analytics SQL easier to maintain.

## The Problem

The analytics projects often accumulate binning logic like this:

```sql
case
    when amount < 10 then '0-10'
    when amount < 50 then '10-50'
    when amount < 200 then '50-200'
    else '200+'
end
```

There is nothing wrong with this query by itself.

The problem is that the same business logic often ends up copied across multiple models, dashboards, notebooks, and reports.

Then a threshold changes.

```text
0-10
10-50
50-200
200+
```

becomes

```text
0-25
25-80
80-199
199+
```

Someone now has to find every CASE WHEN statement and update it correctly.

The work is repetitive, difficult to review, and surprisingly easy to get wrong.

## A Simpler Approach

Instead of storing the rules inside many CASE WHEN statements, store the thresholds as data.

For example:

```text
threshold
---------
0
10
50
200
```

This can be a small table or a dbt seed.

Once the thresholds exist as data, the bin definitions can be generated automatically.

> To keep the core concept easy to understand, we’ll first look at a simplified version that handles basic inner boundaries. Later, we'll see how the actual `dbt-binning` package automatically handles open-ended edges like <0 or 200+ under the hood.

### Step 1: Store Thresholds

```sql
create table thresholds (
    threshold int primary key
);

insert into thresholds values
(0),
(10),
(50),
(200);
```

The table only stores boundaries.

### Step 2: Generate Bin Definitions

Using a window function:

```sql
create view bins AS
select
    threshold as bin_start,
    lead(threshold) over (
        order by threshold
    ) as bin_end,
    ... as label
from thresholds
```

Which becomes:

| bin_start | bin_end | label  |
| --------- | ------- | ------ |
| 0         | 10      | 0-10   |
| 10        | 50      | 10-50  |
| 50        | 200     | 50-200 |
| 200       | null    | 200+   |

From there, labels can be generated automatically.

The SQL for this step rarely changes.

Once you choose an interval convention, it can be reused for many different binning problems.

### Step 3: Join Where Needed

Instead of repeating CASE WHEN logic:

```sql
select
    u.*,
    b.label
from users u
left join bins_with_labels b
    on u.amount >= b.bin_start
   and (
        b.bin_end is null
        or u.amount < b.bin_end
   )
```

Now threshold changes only require updating a small configuration table.

The join logic stays the same.

## Why We Need This Pattern

A few things become easier:

* Thresholds are visible in one place
* Changes are easier to review in Git
* Labels stay consistent
* The same logic can be reused across models
* There is less SQL to maintain

Most importantly, this shifts your workflow from hardcoding business rules in SQL to managing configuration as data.

## Turning It Into a dbt Package

If you use `dbt` for your analytics data pipeline, I packaged it into a small dbt package called `dbt-binning`, it:

* Store thresholds as data
* Generate bins automatically
* Reduce repetitive CASE WHEN / JOIN maintenance

## How to Use the `dbt-binning`

### Generate bins

```sql
-- models/amount_bins.sql
{{ generate_bins(ref('amount_thresholds')) }}
```

`amount_bins` is intentionally materialized as a view. 

Threshold tables are usually small, and keeping generated ranges as a view makes changes easy to
inspect.

#### Output

| bin_start | bin_end | label  |
| --------- | ------- | ------ |
| null      | 0       | <0     |
| 0         | 10      | 0-10   |
| 10        | 50      | 10-50  |
| 50        | 200     | 50-200 |
| 200       | null    | 200+   |

Finite labels use continuous boundaries: `0-10` means `[0, 10)`, including the start value and excluding the end value. Open-ended labels like `200+` (or `<0`) include all values greater than or equal to the start (or smaller than the end).

### Join from another model

The package provides a `bin_join` macro to handles the join condition automatically:

```sql
-- models/orders_with_amount_bins.sql
select
    orders.order_id,
    orders.amount,
    amount_bins.label as amount_bin

from {{ ref('orders') }} as orders
{{ bin_join(
    value='orders.amount',
    bins=ref('amount_bins'),
    bins_alias='bins'
) }}
```

_Note: `bins_alias` is optional and defaults to `bins`._

#### Under the hood

The macro expands to a standard SQL left join, replacing manual boundary join:

```sql
left join {{ ref('amount_bins') }} as bins
    on (
        bins.bin_start is null
        and orders.amount < bins.bin_end
    )
    or (
        bins.bin_start is not null
        and orders.amount >= bins.bin_start
        and (
            orders.amount < bins.bin_end
            or bins.bin_end is null
        )
    )
```

This replaces a repeated `case when amount ... then ... end` block with one threshold seed, one generated bins model, and ordinary SQL joins wherever the bin is needed.

> **Why not use `BETWEEN`?** > > Using `between b.bin_start and b.bin_end` creates overlapping boundaries for continuous data (e.g., is `10.0` in `0-10` or `10-50`?). This inequality join guarantees **half-open intervals `[start, end)`**, ensuring each value falls into exactly one bin.


### Validate thresholds

```yaml
version: 2

seeds:
  - name: amount_thresholds
    tests:
      - thresholds_not_null
```

The package expects the seed/table to contain a column named `threshold`. The included `thresholds_not_null` test ensures no boundary values are missing.

Duplicate thresholds are ignored when bins are generated, so repeated values do not create invalid zero-width ranges.