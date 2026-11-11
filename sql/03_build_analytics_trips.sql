-- 03_build_analytics_trips.sql
-- Builds analytics.trips: every raw row is kept, with an is_valid flag and a single
-- invalid_reason (the FIRST rule the row fails). Derived fields support the KPIs.
-- Thresholds (3 hours, 100 miles, 80 mph) are my own judgment calls.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE analytics.trips AS
WITH base AS (
  SELECT
    t.vendorid,
    t.tpep_pickup_datetime  AS pickup_ts,
    t.tpep_dropoff_datetime AS dropoff_ts,
    t.passenger_count,
    t.trip_distance,
    t.pulocationid,
    t.dolocationid,
    t.payment_type,
    t.fare_amount,
    t.tip_amount,
    t.tolls_amount,
    t.total_amount,
    t.source_file,
    EXTRACT(EPOCH FROM (t.tpep_dropoff_datetime - t.tpep_pickup_datetime)) / 60.0
      AS duration_min
  FROM raw.yellow_trips t
),
flagged AS (
  SELECT b.*,
    CASE
      WHEN pickup_ts < '2022-08-01' OR pickup_ts >= '2022-11-01'
        THEN 'pickup_outside_period'
      WHEN duration_min <= 0   THEN 'non_positive_duration'
      WHEN duration_min > 180  THEN 'duration_over_3h'
      WHEN trip_distance <= 0  THEN 'zero_or_negative_distance'
      WHEN trip_distance > 100 THEN 'distance_over_100_miles'
      WHEN fare_amount <= 0 OR total_amount <= 0
        THEN 'non_positive_fare'
      WHEN pulocationid IS NULL OR dolocationid IS NULL
        OR pulocationid NOT IN (SELECT locationid FROM raw.taxi_zones)
        OR dolocationid NOT IN (SELECT locationid FROM raw.taxi_zones)
        THEN 'invalid_location'
    END AS invalid_reason
  FROM base b
)
SELECT
  f.*,
  (f.invalid_reason IS NULL)                         AS is_valid,
  (f.passenger_count IS NULL OR f.passenger_count = 0) AS passenger_missing,
  CASE WHEN f.duration_min > 0
       THEN f.trip_distance / (f.duration_min / 60.0) END AS avg_speed_mph,
  CAST(f.pickup_ts AS DATE)                          AS pickup_date,
  EXTRACT(HOUR FROM f.pickup_ts)::INT                AS pickup_hour,
  EXTRACT(ISODOW FROM f.pickup_ts)::INT              AS weekday_num,
  TO_CHAR(f.pickup_ts, 'Dy')                         AS weekday_name
FROM flagged f;

-- Indexes to speed up the KPI queries
CREATE INDEX idx_trips_valid_hour ON analytics.trips (is_valid, pickup_hour);
CREATE INDEX idx_trips_valid_pu   ON analytics.trips (is_valid, pulocationid);
ANALYZE analytics.trips;

-- Speed sanity check on valid trips (used to choose the 80 mph rule)
SELECT
  CASE
    WHEN avg_speed_mph < 2  THEN '1) under 2 mph'
    WHEN avg_speed_mph < 5  THEN '2) 2-5 mph'
    WHEN avg_speed_mph < 15 THEN '3) 5-15 mph'
    WHEN avg_speed_mph < 30 THEN '4) 15-30 mph'
    WHEN avg_speed_mph < 60 THEN '5) 30-60 mph'
    WHEN avg_speed_mph < 80 THEN '6) 60-80 mph'
    ELSE '7) 80+ mph'
  END AS speed_band,
  COUNT(*) AS trips
FROM analytics.trips
WHERE is_valid
GROUP BY 1
ORDER BY 1;

-- Extra rule: average speed strictly over 80 mph is treated as a data error.
-- (Run once. My run flagged 9,594 trips.)
UPDATE analytics.trips
SET invalid_reason = 'speed_over_80_mph',
    is_valid = FALSE
WHERE is_valid
  AND avg_speed_mph > 80;

ANALYZE analytics.trips;

-- Final validation summary (my run: 9,762,691 valid trips = 97.51%)
SELECT COALESCE(invalid_reason, 'VALID') AS status,
       COUNT(*) AS trips,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM analytics.trips
GROUP BY 1
ORDER BY trips DESC;
