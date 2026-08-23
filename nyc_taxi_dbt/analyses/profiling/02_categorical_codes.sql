/*
    PASS 3 — Categorical distributions vs. the data dictionary.

    Question: for every low-cardinality coded column, what values actually
    appear, and are they all documented by the TLC?

    This is the highest-yield profiling pass and the easiest to skip. Stacking
    the columns into one result set makes it cheap to eyeball everything at
    once, and the `is_documented` flag turns "read the dictionary carefully"
    into something the query answers for you.

    Findings:
      - payment_type = 0     (4,812,280 rows) -- undocumented
      - RatecodeID  = 99     (  637,889 rows) -- undocumented
      - VendorID 6 and 7 are recent additions not in older dictionary versions
    -> decoded both undocumented codes as 'Unknown' rather than dropping them,
       and left vendor_id as a raw code instead of guessing at vendor names.
*/

with source as (

    select * from {{ source('raw_taxi', 'yellow_tripdata') }}

),

stacked as (

    select 'vendor_id'       as column_name, cast("VendorID" as varchar)    as code from source
    union all
    select 'rate_code_id',    cast("RatecodeID" as varchar)                        from source
    union all
    select 'payment_type_id', cast(payment_type as varchar)                        from source
    union all
    select 'passenger_count', cast(passenger_count as varchar)                     from source
    union all
    select 'store_and_fwd',   store_and_fwd_flag                                   from source

)

select
    column_name,
    coalesce(code, '<null>') as code,
    count(*) as trips,
    round(100.0 * count(*) / sum(count(*)) over (partition by column_name), 2) as pct_of_column,

    -- values the TLC trip record dictionary actually defines
    case
        when code is null then false
        when column_name = 'vendor_id'       then code in ('1', '2', '6', '7')
        when column_name = 'rate_code_id'    then code in ('1', '2', '3', '4', '5', '6')
        when column_name = 'payment_type_id' then code in ('1', '2', '3', '4', '5', '6')
        when column_name = 'store_and_fwd'   then code in ('Y', 'N')
        when column_name = 'passenger_count' then cast(code as integer) between 1 and 9
    end as is_documented

from stacked
group by column_name, code
order by column_name, trips desc
