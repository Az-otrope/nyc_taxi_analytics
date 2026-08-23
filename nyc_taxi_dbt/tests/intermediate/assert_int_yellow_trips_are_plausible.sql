-- Mirrors tests/staging/assert_yellow_trips_are_plausible.sql, but at
-- error severity: this is the layer that promises the noise is gone, so
-- any row that shows up here means the filter in int_yellow_trips.sql
-- needs to be revisited.

select
    trip_id,
    pickup_datetime,
    dropoff_datetime,
    trip_distance_miles,
    total_amount
from {{ ref('int_yellow_trips') }}
where dropoff_datetime <= pickup_datetime
   or total_amount < 0
   or trip_distance_miles <= 0
   or pickup_datetime < '2009-01-01'
