# dbt-binning

Stop Maintaining CASE WHEN Binning Logic in SQL.

**A small dbt package for replacing repetitive CASE WHEN binning logic with threshold tables and reusable joins.**

* Store thresholds as data
* Generate bins automatically
* Reduce repetitive CASE WHEN / JOIN maintenance

---

## The Problem

The analytics projects often accumulate binning logic like this:

```sql
case
    when amount < 0 then '<0'
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
<0
0-10
10-50
50-200
200+
```

becomes

```text
<0
0-25
25-80
80-199
199+
```

Someone now has to find every CASE WHEN statement and update it correctly.

The work is repetitive, difficult to review, and surprisingly easy to get wrong.

## How It Works

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

Once the thresholds exist as data, the bin definitions can be generated automatically.

### Step 2: Generate Bin Definitions

Using a window function:

```sql
-- Wrapped by: dbt_binning.generate_bins(threshold_relation)
create view bins AS
select
    threshold as bin_start,
    lead(threshold) over (
        order by threshold
    ) as bin_end,
    -- a fixed way to generate formatted label
    ... as bin_label
from thresholds
```

Which becomes:

| bin_start | bin_end | bin_label |
| --------- | ------- | --------- |
| null      | 0       | <0        |
| 0         | 10      | 0-10      |
| 10        | 50      | 10-50     |
| 50        | 200     | 50-200    |
| 200       | null    | 200+      |

From there, labels can be generated automatically.

The SQL for this step rarely changes.

Once you choose an interval convention, it can be reused for many different binning problems.

### Step 3: Join Where Needed

Instead of repeating CASE WHEN logic, the join logic stays the same:

```sql
select
    orders.order_id,
    orders.amount,
    bins.bin_label as amount_bin
from {{ ref('orders') }} as orders

-- Wrapped by: dbt_binning.join_bins(...)
left join bins as bins
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

Now threshold changes only require updating a small configuration table.

**Benefits:**

* Thresholds are visible in one place
* Changes are easier to review in Git
* Labels stay consistent
* The same logic can be reused across models
* There is less SQL to maintain

---

## Installation

Include the following in your `packages.yml` file:

```yaml
packages:
  - git: "https://github.com/bchaoss/dbt-binning.git"
    revision: 1.0.0
```

Run `dbt deps` to install the package.

For more information on using packages in your dbt project, check out the [dbt Documentation](https://docs.getdbt.com/docs/build/packages?version=1.11&name=Core).

## Usage

### generate_bins ([source](https://github.com/bchaoss/dbt-binning/blob/main/macros/generate_bins.sql))

The macro `dbt_binning.generate_bins` generates reusable bin definitions from a threshold table or seed.

**Usage:**
```sql
-- models/bins_model_name.sql
{{ dbt_binning.generate_bins(threshold_relation=ref('thresholds_model_name')) }}
-- Generates the bins VIEW from thresholds config
```

**Parameters:**

- `threshold_relation`: model containing a numeric `threshold` column.

Returns a view exposing three columns:

- bin_start
- bin_end
- bin_label

> _Note:_ 
> 
> - **`generate_bins` materializes the bins model as a view by design.** Threshold tables are usually small, and keeping them as views makes changes easy to inspect.
> 
> - **Column `bin_label` follows one of three formats**, to ensure that each value maps to exactly one bin:
>   - "start-end" represents `[start, end)`;
>   - "start+" includes values greater than or equal to `start`;
>   - "<end" includes values smaller than `end`.
> 
> - **Threshold values must be numeric**: non-numeric values will fail during execution; NULL and duplicate values will be ignored.

### join_bins ([source](https://github.com/bchaoss/dbt-binning/blob/main/macros/join_bins.sql))

The macro `dbt_binning.join_bins` handles the join condition automatically.

**Usage:**
```sql
-- models/model_with_bins.sql
select
    source.id,
    source.value_column,
    bins.bin_label as value_bin

from {{ ref('source_model_name') }} as source
{{ dbt_binning.join_bins(
    value_column='source.value_column',
    bins=ref('bins_model_name'),
    bins_alias='bins'
) }} -- Handles the LEFT JOIN logic automatically
```

**Parameters:**

- `value_column`: the expression to classify into bins.
- `bins`: the generated bins relation.
- `bins_alias`: optional alias for the joined bins relation. Defaults to `bins`.