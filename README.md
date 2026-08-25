# nyc_taxi_analytics

A dbt + DuckDB project modelling NYC TLC yellow taxi trip records (~19M rows, Jan–May
2026). Built locally, no dbt Cloud, no warehouse bill.

The dataset is deliberately unremarkable. What this repo is meant to show is the
**decision layer**: why each model exists, what grain it holds, which rows were dropped
and on whose authority, and which tests are load-bearing versus decorative. Every
non-obvious choice is commented at the point of the choice, in the model that makes it.

## Model layout

| Layer | Materialisation | Rule |
|---|---|---|
| `staging` | view | 1:1 with source. Rename, cast, decode. **No business logic, no filtering.** |
| `intermediate` | view | Business logic: row exclusion, joins, derived metrics. |
| `marts` | table | The consumer contract. Explicit columns, tested, documented. |

### Grain

| Model | Grain | Key |
|---|---|---|
| `stg_yellow_trips` | one row per trip record in the source files | `trip_id` (md5 surrogate) |
| `stg_taxi_zones` | one row per TLC location id | `location_id` |
| `int_yellow_trips` | one row per **plausible** trip (~95.2% of source) | `trip_id` |
| `int_yellow_trips_zone_enriched` | one row per plausible trip | `trip_id` |
| `int_yellow_trips_derived_metrics` | one row per plausible trip | `trip_id` |
| `fct_yellow_trips` | one row per plausible trip | `trip_id` |
| `dim_taxi_zones` | one row per TLC location id | `location_id` |

**Known caveat on the fact table:** `int_yellow_trips` excludes ~4.8% of source rows
(915k of 19M) that cannot describe a real trip — dropoff at or before pickup, negative
total, non-positive distance, pickup predating the TLC programme. Anyone summing revenue
off `fct_yellow_trips` is summing plausible revenue, not gross source revenue. The
reconciliation lives in `analyses/profiling/`.

## Running it

```bash
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Download raw Parquet into nyc_taxi_dbt/data/raw/ from
# https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
# (gitignored -- ~326 MB)

cd nyc_taxi_dbt
dbt seed
dbt build
dbt docs generate && dbt docs serve
```

## Testing approach

Generic tests (`unique`, `not_null`, `relationships`, `accepted_values`) cover structure.
The tests that carry actual weight are:

- **`schema_columns_match_set`** (custom, `macros/`) — `union_by_name=true` tolerates
  column drift across monthly files rather than erroring on it, which means a new or
  removed TLC column would otherwise pass through silently. This is the only thing that
  catches it.
- **`assert_yellow_trips_are_plausible`** / **`assert_int_yellow_trips_are_plausible`** —
  singular tests asserting the exclusion rules held, at both ends of the filter.
- **`relationships`** on pickup/dropoff location ids — the guarantee that makes the
  double zone join in `int_yellow_trips_zone_enriched` safe from fan-out.

## Stack

dbt-core 1.11 · dbt-duckdb 1.10 · DuckDB 1.5 · local `dev.duckdb`
