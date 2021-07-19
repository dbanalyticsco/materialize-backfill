with base as (

    select *
    from {{ source('frankenmovies','tracks_s3') }}
    where text != ''

), fields as (

    select 
        text::json->>'anonymousId' as anonymous_id,
        cast(text::json->>'timestamp' as timestamp) as event_timestamp,
        text::json->>'messageId' as event_id
    from base

)

select *
from fields