-- models/amount_bins.sql

{{ dbt_binning.generate_bins(ref('amount_thresholds')) }}
