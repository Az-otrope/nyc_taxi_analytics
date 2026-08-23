/*
    PASS 4 — Null structure, and whether nulls move together.

    Question: which columns are null, and are those nulls independent?

    This is the pass that changed how the whole model was written. Counting
    nulls column by column is routine; the insight is in comparing the counts.
    Random data loss produces *different* counts per column. Identical counts
    across unrelated columns mean a single structural cause.

    Here five columns are null on exactly the same 4,812,280 rows, and those
    same rows carry the undocumented payment_type = 0 (a zero, not a null --
    which is why it shows 0% null below and has to be read alongside pass 3).
    That is not corruption: it is a vendor feed that does not populate the
    optional block at all.

    -> documented as expected behaviour in the model description rather than
       tested against or filtered out. A not_null test on passenger_count would
       fail 25% of the time for a reason that is not a data quality problem.
*/

with source as (

    select * from {{ source('raw_taxi', 'yellow_tripdata') }}

),

null_counts as (

    select 'passenger_count'      as column_name, count(*) filter (where passenger_count is null)      as null_rows from source
    union all
    select 'rate_code_id',              count(*) filter (where "RatecodeID" is null)          from source
    union all
    select 'store_and_fwd_flag',        count(*) filter (where store_and_fwd_flag is null)    from source
    union all
    select 'congestion_surcharge',      count(*) filter (where congestion_surcharge is null)  from source
    union all
    select 'airport_fee',               count(*) filter (where "Airport_fee" is null)         from source
    union all
    select 'cbd_congestion_fee',        count(*) filter (where cbd_congestion_fee is null)    from source
    union all
    select 'payment_type',              count(*) filter (where payment_type is null)          from source

),

total as (select count(*) as total_rows from source)

select
    n.column_name,
    n.null_rows,
    round(100.0 * n.null_rows / t.total_rows, 2) as pct_null,

    -- columns sharing a non-zero null count are almost certainly nulled by
    -- one common cause rather than independently
    n.null_rows > 0
        and count(*) over (partition by n.null_rows) > 1 as shares_null_count

from null_counts n
cross join total t
order by n.null_rows desc, n.column_name
