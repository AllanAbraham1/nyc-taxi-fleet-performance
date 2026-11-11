-- 05_build_dashboard_tables.sql
-- Small summary tables used by the Tableau dashboard (exported to CSV, because
-- Tableau Public cannot connect to PostgreSQL). Run the whole script.

CREATE SCHEMA IF NOT EXISTS dash;

-- 1. Demand heatmap, normalised per day.
-- Excludes 2022-09-18, a day with only about 4,000 records (likely incomplete source data).
DROP TABLE IF EXISTS dash.demand_by_weekday_hour;
CREATE TABLE dash.demand_by_weekday_hour AS
WITH d AS (
  SELECT weekday_num, COUNT(DISTINCT pickup_date) AS days_in_period
  FROM analytics.trips
  WHERE is_valid AND pickup_date <> '2022-09-18'
  GROUP BY weekday_num
)
SELECT t.weekday_num, t.weekday_name, t.pickup_hour,
       COUNT(*) AS trips,
       ROUND(COUNT(*)::numeric / d.days_in_period, 1) AS avg_trips_per_day
FROM analytics.trips t
JOIN d ON d.weekday_num = t.weekday_num
WHERE t.is_valid AND t.pickup_date <> '2022-09-18'
GROUP BY t.weekday_num, t.weekday_name, t.pickup_hour, d.days_in_period;

-- 2. Hourly KPIs
DROP TABLE IF EXISTS dash.hourly_kpis;
CREATE TABLE dash.hourly_kpis AS
SELECT pickup_hour,
       COUNT(*) AS trips,
       ROUND(AVG(duration_min), 1) AS avg_duration_min,
       ROUND(AVG(trip_distance), 2) AS avg_distance_mi,
       ROUND(SUM(trip_distance) / (SUM(duration_min) / 60.0), 1) AS avg_speed_mph,
       ROUND(AVG(fare_amount), 2) AS avg_fare
FROM analytics.trips
WHERE is_valid
GROUP BY pickup_hour;

-- 3. Zone KPIs (all zones, with a volume flag for the 5,000-trip cut-off)
DROP TABLE IF EXISTS dash.zone_kpis;
CREATE TABLE dash.zone_kpis AS
SELECT z.locationid, z.borough, z.zone,
       COUNT(*) AS trips,
       ROUND(AVG(t.fare_amount), 2) AS avg_fare,
       ROUND(AVG(t.trip_distance), 2) AS avg_distance_mi,
       ROUND(AVG(t.duration_min), 1) AS avg_duration_min,
       ROUND(SUM(t.fare_amount) / SUM(t.duration_min), 2) AS fare_per_minute,
       ROUND(SUM(t.fare_amount) / NULLIF(SUM(t.trip_distance), 0), 2) AS fare_per_mile,
       (COUNT(*) >= 5000) AS meets_min_volume
FROM analytics.trips t
JOIN raw.taxi_zones z ON z.locationid = t.pulocationid
WHERE t.is_valid AND COALESCE(z.borough, 'Unknown') <> 'Unknown'
GROUP BY z.locationid, z.borough, z.zone;

-- 4. Daily trend (includes the incomplete day, so the dip stays visible)
DROP TABLE IF EXISTS dash.daily_kpis;
CREATE TABLE dash.daily_kpis AS
SELECT pickup_date, weekday_name,
       COUNT(*) AS trips,
       ROUND(SUM(fare_amount)) AS total_fare,
       ROUND(AVG(fare_amount), 2) AS avg_fare,
       ROUND(SUM(trip_distance) / (SUM(duration_min) / 60.0), 1) AS avg_speed_mph
FROM analytics.trips
WHERE is_valid
GROUP BY pickup_date, weekday_name;

-- 5. Data quality breakdown
DROP TABLE IF EXISTS dash.data_quality;
CREATE TABLE dash.data_quality AS
SELECT COALESCE(invalid_reason, 'VALID') AS status,
       COUNT(*) AS trips,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_trips,
       ROUND(SUM(trip_distance)) AS total_miles,
       ROUND(100.0 * SUM(trip_distance) / SUM(SUM(trip_distance)) OVER (), 1) AS pct_of_miles
FROM analytics.trips
GROUP BY 1;

-- 6. All trips vs valid trips
DROP TABLE IF EXISTS dash.kpi_comparison;
CREATE TABLE dash.kpi_comparison AS
SELECT 'All trips' AS dataset, COUNT(*) AS trips,
       ROUND(AVG(fare_amount), 2) AS avg_fare,
       ROUND(AVG(trip_distance), 2) AS avg_distance_mi,
       ROUND(AVG(duration_min), 1) AS avg_duration_min
FROM analytics.trips
UNION ALL
SELECT 'Valid trips only', COUNT(*),
       ROUND(AVG(fare_amount), 2),
       ROUND(AVG(trip_distance), 2),
       ROUND(AVG(duration_min), 1)
FROM analytics.trips
WHERE is_valid;

-- Row-count check (my run: 168, 24, 260, 92, 8, 2)
SELECT 'demand_by_weekday_hour' AS tbl, COUNT(*) FROM dash.demand_by_weekday_hour
UNION ALL SELECT 'hourly_kpis', COUNT(*) FROM dash.hourly_kpis
UNION ALL SELECT 'zone_kpis', COUNT(*) FROM dash.zone_kpis
UNION ALL SELECT 'daily_kpis', COUNT(*) FROM dash.daily_kpis
UNION ALL SELECT 'data_quality', COUNT(*) FROM dash.data_quality
UNION ALL SELECT 'kpi_comparison', COUNT(*) FROM dash.kpi_comparison;
