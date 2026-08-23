{{
    config(
        materialized='view'
    )
}}

with trips as (

    select * from {{ ref('int_yellow_trips_zone_enriched') }}

),

metrics as (

    select
        trips.*,

        date_diff('second', pickup_datetime, dropoff_datetime) / 60.0 as trip_duration_minutes,

        -- duration is always > 0 here (int_yellow_trips already requires
        -- dropoff_datetime > pickup_datetime), so this never divides by zero
        trip_distance_miles
            / (date_diff('second', pickup_datetime, dropoff_datetime) / 3600.0)
            as average_speed_mph,

        -- fare_amount is <= 0 for ~0.05% of plausible trips (voided/adjustment
        -- records that still cleared the total_amount >= 0 filter in
        -- int_yellow_trips); tip percentage is undefined against a
        -- non-positive base, so it's left null rather than divided into a
        -- meaningless number
        case
            when fare_amount > 0 then round(tip_amount / fare_amount * 100, 2)
        end as tip_percentage

    from trips

)

select * from metrics
