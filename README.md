# NYC Taxi Fleet \& Trip Performance Analysis

An end-to-end analytics project on **10 million NYC Yellow Taxi trips (Aug–Oct 2022)**: data loading and validation in PostgreSQL, KPI analysis in SQL, and an interactive Tableau dashboard.

**Live dashboard:** https://public.tableau.com/app/profile/allan.abraham/viz/NYCTaxiFleetTripPerformanceDashboard/FleetTripPerformance

!\[Dashboard preview, part 1](images/Dashboard1.png)

!\[Dashboard preview, part 2](images/Dashboard2.png)

!\[Dashboard preview, part 3](images/Dashboard3.png)

> \*\*Note on the data:\*\* this is public New York City data, not Dubai data. It was chosen because it is a large, messy, real trip-level dataset. The project demonstrates the kind of fleet and trip KPIs a transport or mobility operator reports (demand patterns, trip speed, fare efficiency, data quality), using methods that apply to any trip-level data.

## Business questions

1. When and where is demand highest (hour, weekday, pickup zone)?
2. Which pickup zones earn the most fare per minute?
3. How do trip duration and average speed change through the day?
4. How many records are anomalies, and how much do they distort the KPIs?

## Tools

PostgreSQL 18, pgAdmin 4, Python (pandas, pyarrow, psycopg2), Tableau Public.

## Data

* **Source:** NYC Taxi \& Limousine Commission (TLC) Yellow Taxi Trip Records, Aug–Oct 2022 (Parquet), accessed through a Kaggle copy, plus the TLC taxi zone lookup (CSV). Check the TLC website for the data terms of use.
* **Volume:** 10,011,855 trips (Aug 3,152,677 / Sep 3,183,767 / Oct 3,675,411).
* The raw data is not included in this repository because of its size.

## Method

1. **Load:** a Python script reads each Parquet file in chunks and bulk-loads it into PostgreSQL with `COPY` (`raw` schema).
2. **Profile:** SQL checks for impossible dates, durations, distances, fares and locations.
3. **Validate (flag, don't delete):** every row is kept in `analytics.trips` with an `is\_valid` flag and a single `invalid\_reason` (the first rule that fails). This makes the cleaning auditable.
4. **Analyse:** KPI queries on valid trips (demand, zones, fare per minute, speed by hour).
5. **Publish:** small summary tables are exported to CSV and visualised in Tableau Public, which cannot connect to PostgreSQL directly.

### Validation rules and results

|Rule (in order applied)|Trips flagged|
|-|-|
|Pickup outside Aug–Oct 2022|53|
|Duration of 0 or less|6,919|
|Duration over 3 hours|11,523|
|Distance of 0 or less|158,353|
|Distance over 100 miles|350|
|Fare or total of 0 or less|62,372|
|Pickup/dropoff location not in the zone lookup|0|
|Average speed over 80 mph|9,594|
|**Total flagged**|**249,164 (2.49%)**|
|**Valid trips**|**9,762,691 (97.51%)**|

Each trip is counted under the first rule it fails, so the categories do not overlap. The thresholds (3 hours, 100 miles, 80 mph) are my own judgment calls, not industry standards.

## Key findings

All figures come from the queries in this repository.

* **A handful of bad records distorted the distance KPI.** 350 trips with distances over 100 miles (some in the hundreds of thousands of miles) made up **42.3%** of all recorded miles. The raw average trip distance is 6.34 miles versus **3.70** for valid trips, while average fare barely changes ($15.26 vs $15.21).
* **Airports and Manhattan drive pickup demand.** JFK Airport is the top pickup zone with 516,758 valid trips, followed by Upper East Side South (448,038) and Midtown Center (394,452). LaGuardia ranks 11th (278,582).
* **Evening is the busiest period and the slowest.** Demand peaks at 18:00 (682,676 valid trips) and is lowest at 04:00 (54,236). Average speed is lowest at 17:00 (11.5 mph) and highest at 05:00 (25.1 mph).
* **Thursday is the busiest weekday and Sunday the quietest.** Thursday averages 117,163 trips per day versus 93,405 on Sunday, about 25% more (excluding 18 Sep, see below).
* **Airports earn well per minute.** JFK averages $1.12 of metered fare per minute and LaGuardia $1.04. Sunnyside tops the ranking at $1.21 but on only 7,345 trips, so it is a small-sample result.

## Limitations

* **New York, three months.** The patterns may not apply to other cities, and three months cannot show seasonality.
* **Incomplete day in the source data:** 18 Sep 2022 has only about 4,000 records (raw table included), versus roughly 80,000–130,000 on a typical day. It is kept in the totals and the daily chart, but excluded from weekday and weekday-by-hour averages. Other hourly and zone figures include it (3,833 valid trips, about 0.04% of the data). 17 Sep is also lower than a typical Saturday.
* **Speed is not a pure congestion measure.** Average speed also reflects trip mix: early-morning trips are longer on average (6.51 miles at 05:00 vs 3.50 at 17:00).
* **Fare per minute** uses metered fare only (no tips or tolls) and only zones with at least 5,000 valid pickups; that cut-off is a judgment call.
* Descriptive analysis only: no causes are claimed for the patterns above.

## Repository structure

```
sql/        numbered SQL scripts (schema, profiling, cleaning, KPIs, dashboard tables)
python/     load\_trips.py (chunked Parquet to PostgreSQL loader)
exports/    summary CSV files used by the Tableau dashboard
images/     dashboard screenshot
```

## How to reproduce

1. Install PostgreSQL and create a database named `fleet\_analytics`.
2. Download the Aug–Oct 2022 Yellow Taxi Parquet files and the taxi zone lookup CSV from the TLC.
3. Run the SQL scripts in `sql/` in numeric order.
4. Edit the connection settings and file paths in `python/load\_trips.py` (use your own password; never commit it), then run it.
5. Open the CSV files in `exports/` in Tableau Public to rebuild the dashboard.

## Author

Allan Abraham Maret — [LinkedIn](https://linkedin.com/in/allan2004) · [GitHub](https://github.com/AllanAbraham1)

