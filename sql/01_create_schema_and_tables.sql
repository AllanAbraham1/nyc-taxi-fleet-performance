-- 01_create_schema_and_tables.sql
-- Raw layer: trips exactly as loaded from the TLC Parquet files, plus the zone lookup.
-- Run this in a database named fleet_analytics.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.yellow_trips (
    vendorid               INT,
    tpep_pickup_datetime   TIMESTAMP,
    tpep_dropoff_datetime  TIMESTAMP,
    passenger_count        NUMERIC,
    trip_distance          NUMERIC,
    ratecodeid             NUMERIC,
    store_and_fwd_flag     TEXT,
    pulocationid           INT,
    dolocationid           INT,
    payment_type           INT,
    fare_amount            NUMERIC,
    extra                  NUMERIC,
    mta_tax                NUMERIC,
    tip_amount             NUMERIC,
    tolls_amount           NUMERIC,
    improvement_surcharge  NUMERIC,
    total_amount           NUMERIC,
    congestion_surcharge   NUMERIC,
    airport_fee            NUMERIC,
    source_file            TEXT
);

CREATE TABLE raw.taxi_zones (
    locationid   INT,
    borough      TEXT,
    zone         TEXT,
    service_zone TEXT
);

-- Loading the data:
--   1) raw.taxi_zones: in pgAdmin, right-click the table > Import/Export Data > Import,
--      choose taxi_zone_lookup.csv (format csv, header on, delimiter comma).
--   2) raw.yellow_trips: run python/load_trips.py (reads the Parquet files in chunks).
