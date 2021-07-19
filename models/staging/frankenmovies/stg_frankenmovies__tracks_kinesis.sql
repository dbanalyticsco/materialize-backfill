with base as (

    select *
    from {{ source('frankenmovies','tracks_kinesis') }}

), datatype as (

    select convert_from(data, 'utf8') as text
    from base

), fields as (

    select 
        text::json->>'anonymousId' as anonymous_id,
        cast(text::json->>'timestamp' as timestamp) as event_timestamp,
        text::json->>'messageId' as event_id
    from datatype

)

select *
from fields