{{
    config(
        materialized='view'
    )
}}

with trips as (

    select * from {{ ref('stg_yellow_trips') }}

),

-- there are rows in staging that can't
-- describe a real trip: dropoffs at or before pickup, negative totals,
-- zero/negative distance, and a handful of pickups dated before the TLC
-- program existed. Together these account for ~4.8% of rows (915k of 19M);
-- filtering them once here keeps every downstream model from re-deriving
-- the same checks.
plausible as (

    select *

    from trips

    where dropoff_datetime > pickup_datetime
      and total_amount >= 0
      and trip_distance_miles > 0
      and pickup_datetime >= '2009-01-01'

)

select * from plausible
