{{
    config(
        materialized='view'
    )
}}

with source as (

    select * from {{ ref('taxi_zone_lookup') }}

),

renamed as (

    select

        cast("LocationID" as integer) as location_id,

        -- the lookup uses two different placeholders ('N/A' and 'Unknown') for
        -- the two non-geographic ids (264, 265); collapse them to a single
        -- non-null label so grouping and joining downstream stays clean
        case
            when "Borough" in ('N/A', 'Unknown') then 'Unknown'
            else "Borough"
        end as borough,

        case
            when "Zone" in ('N/A', 'Unknown') then 'Unknown'
            else "Zone"
        end as zone_name,

        case
            when service_zone in ('N/A', 'Unknown') then 'Unknown'
            else service_zone
        end as service_zone,

        -- 264 = unidentified pickup/dropoff, 265 = outside NYC; neither maps to
        -- a real taxi zone, so downstream models can filter on this instead of
        -- hardcoding the ids
        "LocationID" not in (264, 265) as is_known_zone

    from source

)

select * from renamed
