{% docs yellow_trips_source_profile %}

## Source profile: `raw_taxi.yellow_tripdata`

Union of the monthly TLC yellow taxi Parquet files in `data/raw/`, currently
covering 2026-01 through 2026-05. **18,999,282 rows.** Profiled before any
modelling decisions were made; the runnable queries behind every number here
live in `analyses/profiling/`.

### Grain and key

One row per completed trip. The TLC files carry no trip identifier, so
`trip_id` is an md5 hash over vendor, both timestamps, both location ids,
distance and total amount. That combination was verified unique across all 19M
rows before it was adopted — a `unique` test on it runs at `error` severity, so
a future month that breaks the assumption fails the build rather than silently
producing a non-unique key.

### The optional vendor block

Roughly a quarter of all rows — **4,812,280**, or 25.33% — arrive with five
columns null and a sixth zeroed:

| column | state |
|---|---|
| `passenger_count` | null |
| `rate_code_id` | null |
| `store_and_fwd_flag` | null |
| `congestion_surcharge` | null |
| `airport_fee` | null |
| `payment_type` | `0` (undocumented) |

The counts are *identical*, not merely similar. Independent data loss would
produce varying counts per column; one shared count across six unrelated
columns means one shared cause. These rows come from vendors 1, 2 and 6, and
represent a feed that does not populate the optional block at all.

This is documented rather than tested against. A `not_null` test on
`passenger_count` would fail on 25% of the data for a reason that is not a data
quality defect, and a test that always fails is a test everyone learns to
ignore.

### Undocumented codes

Two values appear that the TLC trip record dictionary does not define:

- `payment_type = 0` — 4,812,280 rows (the block above)
- `rate_code_id = 99` — 637,889 rows

Both are decoded to `'Unknown'` in `payment_type_desc` / `rate_code_desc`. The
underlying codes are preserved so nothing is lost.

`passenger_count = 0` (64,863 rows) is also outside the documented 1–9 range.
It is left as-is; zero-passenger trips are plausible for the meter being run
without a fare.

`vendor_id` is deliberately **not** decoded to a vendor name. Codes 6 and 7 are
recent additions and mapping them to company names from memory would be a
guess baked into the warehouse. The `accepted_values` test on it runs at `warn`
so a new vendor surfaces as a notification rather than a build failure.

### Implausible records

**354,705 rows (1.87%)** violate at least one physical constraint:

| anomaly | rows | assessment |
|---|---|---|
| dropoff at or before pickup | 236,375 | physically impossible |
| negative `total_amount` | 118,331 | plausibly legitimate refunds/adjustments |
| pickup before 2009 | 3 | outside file coverage (2001, 2008) |
| pickup on/after 2026-06 | 1 | outside file coverage |

The union is 354,705 rather than the sum because 4 rows are both reversed and
negative.

Separately, **576,744 trips report zero distance** and the maximum distance is
328,522 miles. Median distance and median trip duration (14 minutes) are both
healthy, which confirms this is a tail problem rather than a systemic one.

**None of these rows are filtered here.** Staging is 1:1 with source by design,
so the decision about what to exclude stays visible in the intermediate layer
instead of being silently buried in a `where` clause. They are surfaced by
`assert_yellow_trips_are_plausible`, a singular test at `warn` severity.

{% enddocs %}


{% docs money_precision_rationale %}

Cast from the source's `double` to `decimal(10,2)`.

The TLC files store every monetary field as a float. Floating-point error is
irrelevant on a single trip and material once summed across 19M of them, so the
scale is fixed at the cent level once here rather than being re-handled — or
forgotten — in every downstream aggregate. `decimal(10,2)` comfortably covers
the observed range of -$2,560.20 to $5,530.74.

{% enddocs %}


{% docs taxi_zones_source_profile %}

## Source profile: `taxi_zone_lookup` seed

265 rows, one per TLC taxi zone. Joined to by both `pickup_location_id` and
`dropoff_location_id`; `relationships` tests on both confirm every observed
location id resolves, with no orphans.

Two ids are not real geographic zones and use inconsistent placeholder text in
the raw seed — `264` is `Borough = 'Unknown'` while `265` is `Borough = 'N/A'`.
Both are normalised to `'Unknown'` so the string columns are never null and
never split a group in two, and `is_known_zone` is exposed as a boolean so
downstream models can filter on meaning instead of hardcoding `(264, 265)`.

`zone_name` for 265 is preserved as `'Outside of NYC'`, which keeps the two
distinguishable after normalisation.

{% enddocs %}
