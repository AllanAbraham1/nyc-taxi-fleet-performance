-- 02_profile_data_quality.sql
-- Load checks and data-quality profiling on the raw table. Run each statement on its own.

-- Load check: rows per source file
-- (my run: 3,152,677 / 3,183,767 / 3,675,411)
SELECT source_file, COUNT(*) AS rows
FROM raw.yellow_trips
GROUP BY source_file
ORDER BY source_file;

-- Zone lookup rows (my run: 265)
SELECT COUNT(*) FROM raw.taxi_zones;

-- Pickup date range. The raw files contain dates outside Aug-Oct 2022
-- (my run: 2001-01-01 to 2022-11-01).
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime)
FROM raw.yellow_trips;

-- Profile: how many rows break each candidate rule?
-- A row can break several rules, so these counts overlap.
SELECT
  COUNT(*) AS total_rows,

  COUNT(*) FILTER (WHERE tpep_pickup_datetime < '2022-08-01'
                      OR tpep_pickup_datetime >= '2022-11-01')   AS pickup_outside_aug_oct,

  COUNT(*) FILTER (WHERE tpep_dropoff_datetime <= tpep_pickup_datetime) AS non_positive_duration,

  COUNT(*) FILTER (WHERE tpep_dropoff_datetime - tpep_pickup_datetime
                         > INTERVAL '3 hours')                    AS duration_over_3h,

  COUNT(*) FILTER (WHERE trip_distance <= 0)                      AS zero_or_negative_distance,
  COUNT(*) FILTER (WHERE trip_distance > 100)                     AS distance_over_100_miles,

  COUNT(*) FILTER (WHERE fare_amount <= 0)                        AS non_positive_fare,
  COUNT(*) FILTER (WHERE total_amount <= 0)                       AS non_positive_total,

  COUNT(*) FILTER (WHERE passenger_count IS NULL
                      OR passenger_count = 0)                     AS missing_or_zero_passengers,

  COUNT(*) FILTER (WHERE pulocationid IS NULL
                      OR dolocationid IS NULL)                    AS null_location_ids,

  COUNT(*) FILTER (WHERE pulocationid NOT IN (SELECT locationid FROM raw.taxi_zones)
                      OR dolocationid NOT IN (SELECT locationid FROM raw.taxi_zones))
                                                                  AS location_not_in_lookup
FROM raw.yellow_trips;
