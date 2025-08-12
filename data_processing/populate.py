import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

# Load your cleaned dataset
df = pd.read_csv("Walmart_Data.csv")

# --- Customers ---
customers_df = df[['customer_id', 'customer_age', 'customer_gender', 'customer_income', 'customer_loyalty_level']].drop_duplicates().rename(columns={
    'customer_age': 'age',
    'customer_gender': 'gender',
    'customer_income': 'income',
    'customer_loyalty_level': 'loyalty_level'
})

# --- Stores ---
stores_df = df[['store_id', 'store_location']].drop_duplicates().rename(columns={
    'store_location': 'location'
})

# --- Categories ---
categories_df = df[['category']].drop_duplicates().reset_index(drop=True)
categories_df['category_id'] = categories_df.index + 1
df = df.merge(categories_df, on='category', how='left')

# --- Products ---
products_df = df[['product_id', 'product_name', 'category_id', 'supplier_id', 'unit_price', 'reorder_point', 'reorder_quantity']].drop_duplicates()

# --- Weather ---
weather_df = df[['weather_conditions']].drop_duplicates().reset_index(drop=True)
weather_df['weather_id'] = weather_df.index + 1
df = df.merge(weather_df, on='weather_conditions', how='left')

# --- Payment Methods ---
payment_df = df[['payment_method']].drop_duplicates().reset_index(drop=True)
payment_df['method_id'] = payment_df.index + 1
df = df.merge(payment_df, on='payment_method', how='left')

# --- Promotions ---
promo_df = df[['promotion_type']].dropna().drop_duplicates().reset_index(drop=True)
promo_df['promotion_id'] = promo_df.index + 1
df = df.merge(promo_df, on='promotion_type', how='left')

# --- Transactions ---
transactions_df = df[['transaction_id', 'transaction_date', 'customer_id', 'store_id',
                      'method_id', 'promotion_applied', 'promotion_id', 'weather_id',
                      'stockout_indicator']].rename(columns={
    'method_id': 'payment_method_id',
    'stockout_indicator': 'stockout'
}).drop_duplicates()

# --- TransactionDetails ---
transaction_details_df = df[['transaction_id', 'product_id', 'quantity_sold']].rename(columns={
    'quantity_sold': 'quantity'
}).drop_duplicates()

# --- Inventory (simplified) ---
inventory_df = df[['store_id', 'product_id', 'inventory_level']].drop_duplicates()

# --- PromotionApplications ---
promotion_applications_df = df[
    (df['promotion_applied'] == True) & (df['promotion_id'].notnull())
][['transaction_id', 'promotion_id']].drop_duplicates()

# --- DemandForecast (if exists) ---
include_demand_forecast = {'forecasted_demand', 'actual_demand'}.issubset(df.columns)
if include_demand_forecast:
    demand_forecast_df = df[['transaction_date', 'store_id', 'product_id', 'forecasted_demand', 'actual_demand']].dropna().drop_duplicates()
    demand_forecast_df = demand_forecast_df.rename(columns={'transaction_date': 'forecast_date'})

# --- Connect to PostgreSQL ---
conn = psycopg2.connect(
    dbname="walmart",
    user="postgres",
    password="Irlocx10@",  # Change as needed
    host="localhost",
    port="5432"
)
cursor = conn.cursor()

# --- Prepare insert list ---
inserts = [
    ("Customers", customers_df, ["customer_id", "age", "gender", "income", "loyalty_level"]),
    ("Stores", stores_df, ["store_id", "location"]),
    ("Categories", categories_df.rename(columns={"category": "category_name"}), ["category_id", "category_name"]),
    ("Products", products_df, ["product_id", "product_name", "category_id", "supplier_id", "unit_price", "reorder_point", "reorder_quantity"]),
    ("Weather", weather_df, ["weather_id", "weather_conditions"]),
    ("PaymentMethods", payment_df.rename(columns={"payment_method": "method_name"}), ["method_id", "method_name"]),
    ("Promotions", promo_df, ["promotion_id", "promotion_type"]),
    ("Transactions", transactions_df, ["transaction_id", "transaction_date", "customer_id", "store_id", "payment_method_id", "promotion_applied", "promotion_id", "weather_id", "stockout"]),
    ("TransactionDetails", transaction_details_df, ["transaction_id", "product_id", "quantity"]),
    ("Inventory", inventory_df, ["store_id", "product_id", "inventory_level"]),
    ("PromotionApplications", promotion_applications_df, ["transaction_id", "promotion_id"])
]

if include_demand_forecast:
    inserts.append(("DemandForecast", demand_forecast_df, ["forecast_date", "store_id", "product_id", "forecasted_demand", "actual_demand"]))

# --- Insert into each table ---
for table_name, dataframe, columns in inserts:
    dataframe = dataframe.astype(object).where(pd.notnull(dataframe), None)
    values = [tuple(row) for row in dataframe[columns].values]
    insert_query = f"""
        INSERT INTO {table_name} ({', '.join(columns)})
        VALUES %s
        ON CONFLICT DO NOTHING;
    """
    execute_values(cursor, insert_query, values)
    print(f" Inserted into {table_name}")

# --- Commit and Close ---
conn.commit()
cursor.close()
conn.close()
print(" All data inserted successfully into normalized schema.")
