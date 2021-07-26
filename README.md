# Historic Backfill Example for Materialize

## Summary

The purpose of this repository is to demonstrate how a streaming source in Materialize can be backfilled with data from S3. 

This is necessary because streaming sources like [Amazon Kinesis](https://aws.amazon.com/kinesis/) only stores data for a limited period of time. For example, the default retention period for Kinesis is 24 hours. If you'd like to include data prior to the retention period in your views, it requires pulling from a source that stores the historic data, such as S3. 

In this example repository, we have set up a dbt project that consolidates S3 and Kinesis data into a single materialized view of page view events from Segment's event tracking functionality. 

## How to backfill Kinesis data with S3

#### 1. Set up Kinesis source

You can follow [these instructions](https://materialize.com/docs/sql/create-source/json-kinesis/#main) to create a new source in Materialize with data from Kinesis. The command will look like the following:

```sql
CREATE MATERIALIZED SOURCE frankenmovies_kinesis
FROM KINESIS ARN 'arn:aws:kinesis:us-east-2:752338102900:stream/frankenmovies-segment'
WITH (access_key_id='foo', secret_access_key='bar')
FORMAT BYTES;
```

#### 2. Set up S3 source

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

#### 3. Generate a dbt source

In order to use the Materialize sources in dbt, we should create a [dbt source](https://docs.getdbt.com/docs/building-a-dbt-project/using-sources) for the two tables created in the prior steps.

You can find the source in this repo at [`/models/staging/frankenmovies/src_frankenmovies.yml`](/models/staging/frankenmovies/src_frankenmovies.yml).