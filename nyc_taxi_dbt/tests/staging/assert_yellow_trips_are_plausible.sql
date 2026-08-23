{{ config(severity = 'warn') }}

-- The raw TLC files carry a small tail of records that cannot describe a real
-- trip: dropoffs at or before the pickup, negative totals, and pickup dates
-- years outside the month the file covers. Staging deliberately keeps them, so
-- this test warns on the volume rather than failing the build — it is the
-- signal for what the intermediate layer needs to handle.

select
    trip_id,
    pickup_datetime,
    dropoff_datetime,
    trip_distance_miles,
    total_amount
from {{ ref('stg_yellow_trips') }}
where dropoff_datetime <= pickup_datetime
   or total_amount < 0
   or pickup_datetime < '2009-01-01'
