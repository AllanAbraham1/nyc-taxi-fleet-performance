"""
load_trips.py
Loads NYC TLC Yellow Taxi Parquet files into PostgreSQL (table raw.yellow_trips).

Reads each file in chunks and bulk-loads it with COPY, so a 16 GB laptop can handle
millions of rows. Run sql/01_create_schema_and_tables.sql first.

Before running: edit FILES and the connection settings below.
Never commit your real password to GitHub.
"""
import io
import os

import psycopg2
import pyarrow.parquet as pq

FILES = [
    r"C:\fleet_data\yellow_tripdata_2022-08.parquet",
    r"C:\fleet_data\yellow_tripdata_2022-09.parquet",
    r"C:\fleet_data\yellow_tripdata_2022-10.parquet",
]

COLS = ["vendorid", "tpep_pickup_datetime", "tpep_dropoff_datetime",
        "passenger_count", "trip_distance", "ratecodeid",
        "store_and_fwd_flag", "pulocationid", "dolocationid",
        "payment_type", "fare_amount", "extra", "mta_tax", "tip_amount",
        "tolls_amount", "improvement_surcharge", "total_amount",
        "congestion_surcharge", "airport_fee"]

conn = psycopg2.connect(dbname="fleet_analytics", user="postgres",
                        password="YOUR_PASSWORD", host="localhost", port=5432)
cur = conn.cursor()
copy_sql = ("COPY raw.yellow_trips (" + ",".join(COLS) +
            ",source_file) FROM STDIN WITH CSV")

for path in FILES:
    name = os.path.basename(path)
    pf = pq.ParquetFile(path)
    total = 0
    for batch in pf.iter_batches(batch_size=200_000):
        df = batch.to_pandas()
        df.columns = [c.lower() for c in df.columns]
        df = df[COLS]
        df["source_file"] = name
        buf = io.StringIO()
        df.to_csv(buf, index=False, header=False)
        buf.seek(0)
        cur.copy_expert(copy_sql, buf)
        total += len(df)
    conn.commit()
    print(name, "loaded rows:", total)

cur.close()
conn.close()
