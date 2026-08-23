# Source profiling

Runnable profiling queries for `raw_taxi.yellow_tripdata`, written *before* the
staging models and kept in the repo as the evidence behind their design.

These compile with `dbt compile` but never execute on `dbt build` — that is what
the `analyses/` directory is for. To run one:

```bash
dbt compile --select path:analyses/profiling
# then execute target/compiled/nyc_taxi_dbt/analyses/profiling/<file>.sql
```

Findings are written up in `models/staging/_staging__docs.md` and surface on the
dbt docs site as the model descriptions.

## The method

Six passes, each answering a different question. Run in order — later passes
depend on what earlier ones reveal.

| # | Pass | Question | File |
|---|---|---|---|
| 1 | Schema | What columns exist, and are the source's types sensible? | `DESCRIBE` |
| 2 | Grain & key | What is one row, and is anything unique? | `01_grain_and_candidate_key.sql` |
| 3 | Categoricals | Which coded values appear, and are they all documented? | `02_categorical_codes.sql` |
| 4 | Null structure | Where are the nulls, and do they move together? | `03_null_structure.sql` |
| 5 | Ranges | Where are the impossible values? Is the median healthy? | `04_ranges_and_anomalies.sql` |
| 6 | Time & referential | Is the data inside its expected window? Do FKs resolve? | `04_ranges_and_anomalies.sql` |

### Notes on the passes that earn their keep

**Pass 3 — group by every low-cardinality column.** The cheapest pass and the
one most often skipped. Compare what you find against the vendor's data
dictionary; an undocumented code is not automatically corrupt, it is a question
to answer.

**Pass 4 — compare null counts, don't just read them.** Independent data loss
produces *different* counts per column. Identical counts across unrelated
columns mean one structural cause. Finding that reframes "25% of my data is
broken" into "25% of my data comes from a different feed shape", which is a
completely different modelling decision.

**Pass 5 — always include the median, not just min/max.** min/max find the
impossible values; the median tells you whether the problem is systemic or
confined to the tail. The fix differs enormously between those two cases.

## Turning findings into decisions

Not every anomaly deserves a test. The filter:

- **Does it violate physics, or violate my assumptions?**
  A dropoff before its pickup cannot be real — test it. A null `passenger_count`
  only breaks an assumption that the column is always populated — document it.

- **Will the test ever pass?**
  A test that fails on 25% of rows for a known upstream reason is one people
  learn to ignore, which is worse than having no test.

- **`error` or `warn`?**
  `error` for invariants the models depend on (key uniqueness, referential
  integrity). `warn` for upstream reality you are monitoring but have chosen to
  accept.

- **Filter in staging, or downstream?**
  Staging stays 1:1 with source. Exclusions belong in the intermediate layer
  where the decision stays visible, not buried in a staging `where` clause.
