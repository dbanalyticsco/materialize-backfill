{{ config(materialized='table') }}

with unioned as (

    select * from {{ ref('stg_frankenmovies__tracks_s3') }}
    where event_timestamp < (select min(event_timestamp) from {{ ref('stg_frankenmovies__tracks_kinesis') }})
    union all
    select * from {{ ref('stg_frankenmovies__tracks_kinesis') }}

)

select *
from unioned