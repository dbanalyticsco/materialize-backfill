# Historic Backfill Example for Materialize

## Summary

The purpose of this repository is to demonstrate how a streaming source in Materialize can be backfilled with data from S3. 

This is necessary because streaming sources like [Amazon Kinesis](https://aws.amazon.com/kinesis/) only store data for a limited period of time. For example, the default retention period for Kinesis is 24 hours. If you'd like to include data prior to the retention period in your views, it requires pulling from a source that stores the historic data, such as S3. 

In this example repository, we have set up a dbt project that consolidates S3 and Kinesis data into a single materialized view of page view events from Segment's event tracking functionality. 

## How to backfill Kinesis data with S3

### 1. Set up Kinesis source

You can follow [these instructions](https://materialize.com/docs/sql/create-source/json-kinesis/#main) to create a new source in Materialize with data from Kinesis. The command will look like the following:

```sql
CREATE MATERIALIZED SOURCE frankenmovies_kinesis
FROM KINESIS ARN 'arn:aws:kinesis:us-east-2:752338102900:stream/frankenmovies-segment'
WITH (access_key_id='foo', secret_access_key='bar')
FORMAT BYTES;
```

### 2. Set up S3 source

You can follow [these instructions](https://materialize.com/docs/sql/create-source/json-s3/#main) to create a new source in Materialize with data from S3. The command will look like the following:

```sql
CREATE MATERIALIZED SOURCE frankenmovies_s3 
FROM S3 DISCOVER OBJECTS MATCHING 'segment-logs/qv5iYYMxd94DahFpRzm58y/*/*.gz' USING 
    BUCKET SCAN 'frankenmovies-segment',
    SQS NOTIFICATIONS 'frankenmovies-segment'
COMPRESSION GZIP 
WITH (region = 'us-east-2', access_key_id='foo', secret_access_key='bar')
FORMAT TEXT;
```

### 3. Generate a dbt source

In order to use the Materialize sources in dbt, we should create a [dbt source](https://docs.getdbt.com/docs/building-a-dbt-project/using-sources) for the two tables created in the prior steps.

You can find the source in this repo at [`/models/staging/frankenmovies/src_frankenmovies.yml`](/models/staging/frankenmovies/src_frankenmovies.yml).

### 4. Generate staging dbt models

We should then create staging models as a point of abstraction for the dbt sources. Staging models allow you to clean up data (renaming, casting, etc) in one place so that all data used downstream in the dbt project is clean.

You can find the two staging models in this repo on the below links:
* S3: [`/models/staging/frankenmovies/stg_frankenmovies__tracks_s3.sql`](/models/staging/frankenmovies/stg_frankenmovies__tracks_s3.sql)
* Kinesis: [`/models/staging/frankenmovies/stg_frankenmovies__tracks_kinesis.sql`](/models/staging/frankenmovies/stg_frankenmovies__tracks_kinesis.sql)

### 5. Union your data

Now that we have our dbt source and staging models created, we can create the final model that unions our streaming and historic data together. 

We can do the unioning one of two ways:
1. Write the SQL ourselves
2. Use a dbt macro

#### Writing the union ourselves

If we wanted to write the SQL ourself, we need to write a SQL query that (a) has the same columns on both sides of the union and (b) has the columns in the same order. 

In our case, we have written the staging models such that both those criteria are true. We could therefore have a final model that looks like the following:

```sql
with unioned as (

    select *, 's3' as source from {{ ref('stg_frankenmovies__tracks_s3') }}
    where event_timestamp < (select min(event_timestamp) from {{ ref('stg_frankenmovies__tracks_kinesis') }})
    union all
    select *, 'kinesis' as source from {{ ref('stg_frankenmovies__tracks_kinesis') }}

)

select *
from unioned
```

In this query, you can see that we are unioning the two tables together, but only selecting records from the historic S3 data where they occur before the beginning of our streaming Kinesis data. This way, we filter out events that are duplicated across both sources and have high-quality output data. 

We are able to use a `select *` in the query only because we set up the two staging models to have the exact same columns in the exact same order.

This unioning approach is simple enough if we don't have a particularly large number of columns in the unioned data and the two sources have most of the columns in common. When this is not the case and managing the staging models and union statement might be more cumbersone, a dbt macro might be better.

#### Using a dbt macro

In theory, we would like a macro that would take our two staging models as arguments and generates the union statement for us. Fortunately, there is something exactly like this in the [`dbt-utils`](https://github.com/dbt-labs/dbt-utils) package: [the `union_relations` macro](https://github.com/dbt-labs/dbt-utils/blob/master/macros/sql/union.sql).

Unfortunately, that macro will union _all_ data from the two tables. It won't do the `where` clause that ensures duplicated data isn't included twice. 

We have therefore used the `union_relations` macro as inspiration and written our own macro that Materialize users can use to backfill streaming data with historical data. You can see the macro code at [`/macros/union.sql`](/macros/union.sql).

The macro takes three required arguments:
* s3_relation: The dbt model where the S3 data is stored.
* kinesis_relation: The dbt model where the Kinesis data is stored.
* timestamp_column: The timestamp column in both models that should be used for the filter clause. 

You can see the macro in use at [`/models/marts/frankenmovies/fct_tracks.sql`](/models/marts/frankenmovies/fct_tracks.sql):

```sql
{{ union_relations(
    s3_relation=ref('stg_frankenmovies__tracks_s3'),
    kinesis_relation=ref('stg_frankenmovies__tracks_kinesis'),
    timestamp_column='event_timestamp'
) }}
```

The macro will compile to a SQL query similar to that above. It will match up all columns across the two models and insert the `where` clause in the relevant place. 
