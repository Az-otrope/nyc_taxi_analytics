"""
Build a small committed Parquet fixture so CI can run a real `dbt build`.

The full raw data is ~326 MB and gitignored, so CI cannot use it. Compiling
alone would prove nothing -- it would not catch a fan-out, a broken cast, or a
failing test. Instead we commit a deterministic ~50k-row slice that preserves
the schema (including the columns that only appear in later TLC months) and
enough of the dirty tail for the plausibility tests to be meaningful.

Run this once, commit the output, and re-run it only when the source schema
changes.

    python scripts/make_ci_sample.py
"""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "nyc_taxi_dbt" / "data" / "raw"
OUT = ROOT / "nyc_taxi_dbt" / "data" / "ci"
ROWS_PER_MONTH = 10_000

OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()

# One slice per month so union_by_name still has to reconcile differing
# column sets -- that is the exact behaviour the schema test guards.
for src in sorted(RAW.glob("yellow_tripdata_*.parquet")):
    dest = OUT / f"{src.stem}_ci.parquet"
    con.execute(
        f"""
        copy (
            select * from read_parquet('{src.as_posix()}')
            -- deterministic slice: ordered by a hash of the columns that
            -- identify a trip, so the sample is stable across runs (diffs stay
            -- empty unless intent changes) and spread across the file rather
            -- than being the first N rows, which would all be Jan 1st.
            -- Not rowid: that is a table pseudocolumn and does not exist on
            -- read_parquet.
            order by hash(concat_ws('|',
                "VendorID", tpep_pickup_datetime, tpep_dropoff_datetime,
                "PULocationID", "DOLocationID", trip_distance, total_amount
            ))
            limit {ROWS_PER_MONTH}
        ) to '{dest.as_posix()}' (format parquet)
        """
    )
    n = con.execute(
        f"select count(*) from read_parquet('{dest.as_posix()}')"
    ).fetchone()[0]
    print(f"{dest.name:40s} {n:>7,} rows")

total = con.execute(
    f"select count(*) from read_parquet('{(OUT / '*.parquet').as_posix()}', union_by_name=true)"
).fetchone()[0]
size = sum(f.stat().st_size for f in OUT.glob("*.parquet")) / 1024 / 1024
print(f"\nfixture total: {total:,} rows, {size:.1f} MB")
