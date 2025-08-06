import psycopg2
from pymongo import MongoClient
from datetime import datetime, date
from decimal import Decimal
import time

# PostgreSQL connection
pg_conn = psycopg2.connect(
    dbname='walmart',
    user='postgres',
    password='Irlocx10@',
    host='localhost',
    port='5432'
)

# MongoDB connection
mongo_client = MongoClient('mongodb://localhost:27017')
mongo_db = mongo_client['walmart_realtime']

# All tables including transactions and inventory
tables = [
    "transactions",
    "transactiondetails",
    "inventory",
    "products",
    "customers",
    "stores",
    "categories",
    "paymentmethods",
    "promotions",
    "promotionapplications",
    "weather",
    "demandforecast"
]

# Fix Decimal and date for MongoDB
def safe_cast(val):
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, date) and not isinstance(val, datetime):
        return datetime(val.year, val.month, val.day)
    return val

def backfill_table(table_name):
    print(f" Backfilling: {table_name}")
    with pg_conn.cursor() as cur:
        cur.execute(f"SELECT * FROM {table_name}")
        colnames = [desc[0] for desc in cur.description]
        rows = cur.fetchall()

        if not rows:
            print(f"⚠️  No data found in {table_name}")
            return

        docs = []
        for row in rows:
            row_dict = {k: safe_cast(v) for k, v in zip(colnames, row)}
            doc = {
                "op": "c",
                "after": row_dict,
                "source": {
                    "table": table_name,
                    "db": "walmart",
                    "connector": "batch-etl"
                },
                "ts_ms": int(time.time() * 1000),
                "transaction": None
            }
            docs.append(doc)

        mongo_db[table_name].insert_many(docs)
        print(f"✅ Inserted {len(docs)} documents into MongoDB collection: {table_name}")

# Run batch ETL for each table
for table in tables:
    backfill_table(table)

pg_conn.close()
mongo_client.close()
print("Batch ETL complete. MongoDB now contains all PostgreSQL tables.")
