{% test schema_columns_match_set(model, column_names) %}

{#
    Fails if the relation's actual columns differ from column_names, in
    either direction. Column tests (unique, not_null, ...) only ever look at
    columns we already know about; this is the counterpart that catches a
    column silently appearing or disappearing upstream -- the exact failure
    mode union_by_name on the raw TLC files is prone to (see
    _staging__sources.yml).
#}

{#
    adapter.get_columns_in_relation() needs a real catalog relation, but
    sources here compile to an inline read_parquet(...) via
    meta.external_location rather than a materialized object -- so we
    introspect the compiled query directly instead.
#}
{%- if execute -%}
    {%- set query -%}
        select * from {{ model }} limit 0
    {%- endset -%}
    {%- set actual_columns = run_query(query).column_names | list -%}
{%- else -%}
    {%- set actual_columns = [] -%}
{%- endif -%}

{%- set missing_columns = column_names | reject('in', actual_columns) | list -%}
{%- set extra_columns = actual_columns | reject('in', column_names) | list -%}

with mismatches as (

    select
        '{{ missing_columns | join(", ") }}' as missing_columns,
        '{{ extra_columns | join(", ") }}' as extra_columns

)

select * from mismatches
where missing_columns != '' or extra_columns != ''

{% endtest %}
