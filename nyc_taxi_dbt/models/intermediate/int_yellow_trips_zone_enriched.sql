{{
    config(
        materialized='view'
    )
}}

with trips as (

    select * from {{ ref('int_yellow_trips') }}

),

zones as (

    select * from {{ ref('stg_taxi_zones') }}

),

pickup_zones as (

    select
        location_id,
        borough as pickup_borough,
        zone_name as pickup_zone_name,
        service_zone as pickup_service_zone,
        is_known_zone as pickup_is_known_zone
    from zones

),

dropoff_zones as (

    select
        location_id,
        borough as dropoff_borough,
        zone_name as dropoff_zone_name,
        service_zone as dropoff_service_zone,
        is_known_zone as dropoff_is_known_zone
    from zones

),

-- left joins are defensive rather than load-bearing: stg_yellow_trips
-- already carries a `relationships` test confirming every pickup/dropoff
-- location id resolves to a zone, so these should never introduce nulls.
joined as (

    select
        trips.*,
        pickup_zones.pickup_borough,
        pickup_zones.pickup_zone_name,
        pickup_zones.pickup_service_zone,
        pickup_zones.pickup_is_known_zone,
        dropoff_zones.dropoff_borough,
        dropoff_zones.dropoff_zone_name,
        dropoff_zones.dropoff_service_zone,
        dropoff_zones.dropoff_is_known_zone

    from trips
    left join pickup_zones on trips.pickup_location_id = pickup_zones.location_id
    left join dropoff_zones on trips.dropoff_location_id = dropoff_zones.location_id

)

select * from joined
