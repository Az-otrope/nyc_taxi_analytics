/*
    PASS 1-2 — Grain and candidate key in trip data

    Question: what info does a row carry, how many are there, and is there anything that
    can serve as a primary key?

    The TLC files don't have a trip identifier, so before committing to a
    surrogate key we have to prove that some combination of columns is actually
    unique. If duplicates existed we would need either a different key strategy
    or a dedupe step in staging.

    Finding: 18,999,282 rows, zero duplicates on the seven-column natural key.
    -> justified the md5() surrogate key in stg_yellow_trips.
*/

select
    count(*) as total_rows,

    count(distinct (
        "VendorID",
        tpep_pickup_datetime,
        tpep_dropoff_datetime,
        "PULocationID",
        "DOLocationID",
        trip_distance,
        total_amount
    )) as distinct_natural_keys,

    count(*) - count(distinct (
        "VendorID",
        tpep_pickup_datetime,
        tpep_dropoff_datetime,
        "PULocationID",
        "DOLocationID",
        trip_distance,
        total_amount
    )) as duplicate_rows,

    min(tpep_pickup_datetime) as earliest_pickup,
    max(tpep_pickup_datetime) as latest_pickup

from {{ source('raw_taxi', 'yellow_tripdata') }}
