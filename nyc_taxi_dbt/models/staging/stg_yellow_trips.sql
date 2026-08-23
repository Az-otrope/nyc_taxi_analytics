{{
    config(
        materialized='view'
    )
}}

with source as (

    select * from {{ source('raw_taxi', 'yellow_tripdata') }}

),

renamed as (

    select

        -- surrogate key
        -- the TLC files ship without a trip identifier, so we hash the columns
        -- that together uniquely describe a trip (verified: 0 collisions across
        -- the 19M rows currently in data/raw/)
        md5(
            concat_ws('|',
                "VendorID",
                tpep_pickup_datetime,
                tpep_dropoff_datetime,
                "PULocationID",
                "DOLocationID",
                trip_distance,
                total_amount
            )
        ) as trip_id,

        -- ids
        cast("VendorID" as integer)        as vendor_id,
        cast("RatecodeID" as integer)      as rate_code_id,
        cast(payment_type as integer)      as payment_type_id,
        cast("PULocationID" as integer)    as pickup_location_id,
        cast("DOLocationID" as integer)    as dropoff_location_id,

        -- timestamps
        cast(tpep_pickup_datetime as timestamp)  as pickup_datetime,
        cast(tpep_dropoff_datetime as timestamp) as dropoff_datetime,

        -- trip attributes
        cast(passenger_count as integer)   as passenger_count,
        cast(trip_distance as double)      as trip_distance_miles,

        -- 'Y' = trip was held in vehicle memory before being sent to the vendor
        case store_and_fwd_flag
            when 'Y' then true
            when 'N' then false
        end as is_store_and_forward,

        -- monetary fields: the source stores these as floats, which accumulate
        -- rounding error once summed over millions of rows, so we fix the scale
        -- at the cent level here rather than in every downstream model
        cast(fare_amount as decimal(10, 2))            as fare_amount,
        cast(extra as decimal(10, 2))                  as extra_amount,
        cast(mta_tax as decimal(10, 2))                as mta_tax_amount,
        cast(tip_amount as decimal(10, 2))             as tip_amount,
        cast(tolls_amount as decimal(10, 2))           as tolls_amount,
        cast(improvement_surcharge as decimal(10, 2))  as improvement_surcharge_amount,
        cast(congestion_surcharge as decimal(10, 2))   as congestion_surcharge_amount,
        cast("Airport_fee" as decimal(10, 2))          as airport_fee_amount,
        cast(cbd_congestion_fee as decimal(10, 2))     as cbd_congestion_fee_amount,
        cast(total_amount as decimal(10, 2))           as total_amount,

        -- decoded categoricals (TLC trip record data dictionary)
        case cast(payment_type as integer)
            when 1 then 'Credit card'
            when 2 then 'Cash'
            when 3 then 'No charge'
            when 4 then 'Dispute'
            when 5 then 'Unknown'
            when 6 then 'Voided trip'
            else 'Unknown'
        end as payment_type_desc,

        case cast("RatecodeID" as integer)
            when 1 then 'Standard rate'
            when 2 then 'JFK'
            when 3 then 'Newark'
            when 4 then 'Nassau or Westchester'
            when 5 then 'Negotiated fare'
            when 6 then 'Group ride'
            else 'Unknown'
        end as rate_code_desc

    from source

)

select * from renamed
