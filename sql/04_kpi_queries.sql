-- 04_kpi_queries.sql
-- KPI and investigation queries behind the findings. Run each statement on its own.

-- Check: placeholder zones in the lookup (IDs 264 and 265, excluded from zone rankings)
SELECT * FROM raw.taxi_zones
WHERE COALESCE(borough, 'Unknown') = 'Unknown';

-- Q1. Demand by weekday and hour (valid trips)
SELECT weekday_num, weekday_name, pickup_hour, COUNT(*) AS trips
FROM analytics.trips
WHERE is_valid
GROUP BY weekday_num, weekday_name, pickup_hour
ORDER BY weekday_num, pickup_hour;

-- Q1b. Top 15 pickup zones
SELECT z.borough, z.zone, COUNT(*) AS trips
FROM analytics.trips t
JOIN raw.taxi_zones z ON z.locationid = t.pulocationid
WHERE t.is_valid AND COALESCE(z.borough, 'Unknown') <> 'Unknown'
GROUP BY z.borough, z.zone
ORDER BY trips DESC
LIMIT 15;

-- Q2. Fare efficiency by pickup zone (metered fare only; zones with 5,000+ valid pickups)
SELECT z.borough, z.zone,
       COUNT(*) AS trips,
       ROUND(AVG(t.fare_amount), 2) AS avg_fare,
       ROUND(SUM(t.fare_amount) / SUM(t.duration_min), 2) AS fare_per_minute,
       ROUND(SUM(t.fare_amount) / NULLIF(SUM(t.trip_distance), 0), 2) AS fare_per_mile
FROM analytics.trips t
JOIN raw.taxi_zones z ON z.locationid = t.pulocationid
WHERE t.is_valid AND COALESCE(z.borough, 'Unknown') <> 'Unknown'
GROUP BY z.borough, z.zone
HAVING COUNT(*) >= 5000
ORDER BY fare_per_minute DESC
LIMIT 15;

-- Q3. Duration and speed by hour (speed = total distance / total time)
SELECT pickup_hour,
       COUNT(*) AS trips,
       ROUND(AVG(duration_min), 1) AS avg_duration_min,
       ROUND(AVG(trip_distance), 2) AS avg_distance_mi,
       ROUND(SUM(trip_distance) / (SUM(duration_min) / 60.0), 1) AS avg_speed_mph
FROM analytics.trips
WHERE is_valid
GROUP BY pickup_hour
ORDER BY pickup_hour;

-- Q4. How much do anomalies distort the KPIs? All trips vs valid trips
SELECT 'all trips' AS dataset,
       COUNT(*) AS trips,
       ROUND(AVG(fare_amount), 2) AS avg_fare,
       ROUND(AVG(trip_distance), 2) AS avg_distance_mi,
       ROUND(AVG(duration_min), 1) AS avg_duration_min,
       ROUND(SUM(fare_amount)) AS total_fare
FROM analytics.trips
UNION ALL
SELECT 'valid only',
       COUNT(*),
       ROUND(AVG(fare_amount), 2),
       ROUND(AVG(trip_distance), 2),
       ROUND(AVG(duration_min), 1),
       ROUND(SUM(fare_amount))
FROM analytics.trips
WHERE is_valid;

-- Share of recorded miles by validation status
-- (my run: the 350 trips over 100 miles = 42.3% of all recorded miles)
SELECT COALESCE(invalid_reason, 'VALID') AS status,
       COUNT(*) AS trips,
       ROUND(SUM(trip_distance)) AS total_miles,
       ROUND(100.0 * SUM(trip_distance) / SUM(SUM(trip_distance)) OVER (), 1) AS pct_of_all_miles
FROM analytics.trips
GROUP BY 1
ORDER BY total_miles DESC;

-- The longest recorded trips (all flagged as distance_over_100_miles)
SELECT trip_distance, duration_min, fare_amount, invalid_reason
FROM analytics.trips
ORDER BY trip_distance DESC
LIMIT 10;

-- Lowest-volume days inside the study period (finds the incomplete day, 2022-09-18)
SELECT pickup_date, weekday_name,
       COUNT(*) FILTER (WHERE is_valid) AS valid_trips,
       COUNT(*) AS all_trips
FROM analytics.trips
WHERE pickup_date BETWEEN '2022-08-01' AND '2022-10-31'
GROUP BY pickup_date, weekday_name
ORDER BY valid_trips
LIMIT 5;

-- Average trips per day by weekday, all days
SELECT weekday_num, weekday_name,
       COUNT(*) AS trips,
       COUNT(DISTINCT pickup_date) AS days_in_period,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT pickup_date)) AS avg_trips_per_day
FROM analytics.trips
WHERE is_valid
GROUP BY weekday_num, weekday_name
ORDER BY weekday_num;

-- Average trips per day by weekday, excluding the incomplete day 2022-09-18
-- (my run: Thursday 117,163 vs Sunday 93,405)
SELECT weekday_num, weekday_name,
       COUNT(*) AS trips,
       COUNT(DISTINCT pickup_date) AS days_in_period,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT pickup_date)) AS avg_trips_per_day
FROM analytics.trips
WHERE is_valid
  AND pickup_date <> '2022-09-18'
GROUP BY weekday_num, weekday_name
ORDER BY weekday_num;
