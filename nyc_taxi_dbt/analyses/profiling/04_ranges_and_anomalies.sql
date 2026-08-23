/*
    PASS 5-6 — Continuous ranges, time distribution, and quantified anomalies.

    Question: where are the impossible values, and how many rows do they affect?

    min/max is where physically impossible values hide; the median tells you
    whether the problem is systemic or confined to the tail. Quantifying each
    anomaly separately matters because the decision differs per anomaly:

      - reversed timestamps (236,375) -- physically impossible, cannot be real
      - negative totals     (118,331) -- plausibly legitimate refund adjustments
      - pre-2009 pickups    (      3) -- clearly outside the file's coverage

    Note the union is 354,705, not the sum, because 4 rows are both reversed
    and negative. That number reconciles exactly with the warning raised by
    tests/staging/assert_yellow_trips_are_plausible.sql.

    -> none of these are filtered in staging, which stays 1:1 with source. They
       are surfaced by a warn-severity singular test so the intermediate layer
       can make the call with the volumes in hand.
*/

with source as (

    select
        *,
        datediff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) as trip_minutes
    from {{ source('raw_taxi', 'yellow_tripdata') }}

)

select
    -- continuous ranges: median proves the centre is healthy
    min(fare_amount)            as min_fare,
    max(fare_amount)            as max_fare,
    median(fare_amount)         as median_fare,

    min(trip_distance)          as min_distance,
    max(trip_distance)          as max_distance,
    median(trip_distance)       as median_distance,

    min(trip_minutes)           as min_minutes,
    max(trip_minutes)           as max_minutes,
    median(trip_minutes)        as median_minutes,

    -- anomalies, counted independently so each can be judged on its own
    count(*) filter (where tpep_dropoff_datetime <= tpep_pickup_datetime) as reversed_timestamps,
    count(*) filter (where total_amount < 0)                              as negative_totals,
    count(*) filter (where trip_distance = 0)                             as zero_distance,
    count(*) filter (where tpep_pickup_datetime < date '2009-01-01')      as pre_2009_pickups,
    count(*) filter (where tpep_pickup_datetime >= date '2026-06-01')     as post_coverage_pickups,

    -- overlap, and the union that the singular test reports
    count(*) filter (
        where tpep_dropoff_datetime <= tpep_pickup_datetime
          and total_amount < 0
    ) as reversed_and_negative,

    count(*) filter (
        where tpep_dropoff_datetime <= tpep_pickup_datetime
           or total_amount < 0
           or tpep_pickup_datetime < date '2009-01-01'
    ) as total_implausible

from source
