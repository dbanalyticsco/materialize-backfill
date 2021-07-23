{{ config(materialized='table') }}

-- with unioned as (

--     select *, 's3' as source from {{ ref('stg_frankenmovies__tracks_s3') }}
--     where event_timestamp < (select min(event_timestamp) from {{ ref('stg_frankenmovies__tracks_kinesis') }})
--     union all
--     select *, 'kinesis' as source from {{ ref('stg_frankenmovies__tracks_kinesis') }}

-- )

-- select *
-- from unioned

{{ union_relations(
    s3_relation=ref('stg_frankenmovies__tracks_s3'),
    kinesis_relation=ref('stg_frankenmovies__tracks_kinesis'),
    timestamp_column='event_timestamp'
) }}