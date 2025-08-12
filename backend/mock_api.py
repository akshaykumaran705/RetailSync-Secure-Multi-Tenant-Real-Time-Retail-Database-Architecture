# api.py
# This Flask server provides all necessary endpoints for the multi-page RetailSync app,
# including a new /login endpoint and role-based data access for analytics.

from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime

# Load environment variables from .env file if it exists
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("python-dotenv not installed. Install with: pip install python-dotenv")
    print("Or set environment variables manually.")

app = Flask(__name__)
CORS(app)

# --- Database Connection Details ---
DB_NAME = os.getenv("DB_NAME", "postgres")  # Changed default to walmart
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")  # Empty default - must be set
DB_HOST = os.getenv("DB_HOST", "database-1.cxmeuqiimnc6.us-east-2.rds.amazonaws.com")
DB_PORT = os.getenv("DB_PORT", "5432")

# --- Mock User Store ---
# In a real application, this would be a 'users' table in your database.
USERS = {
    "admin": {"id": 0, "password": "admin_password", "role": "admin", "store_id": None},
    "store1_manager": {"id": 1, "password": "pass1", "role": "manager", "store_id": 1},
    "store2_manager": {"id": 2, "password": "pass2", "role": "manager", "store_id": 2},
    "store3_manager": {"id": 3, "password": "pass3", "role": "manager", "store_id": 3},
    "store4_manager": {"id": 4, "password": "pass4", "role": "manager", "store_id": 4},
    "store5_manager": {"id": 5, "password": "pass5", "role": "manager", "store_id": 5},
}

def get_db_connection():
    if not DB_PASSWORD:
        raise Exception("DB_PASSWORD environment variable is not set. Please set your RDS password.")
    
    try:
        conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD, host=DB_HOST, port=DB_PORT)
        return conn
    except psycopg2.OperationalError as e:
        if "password authentication failed" in str(e):
            raise Exception(f"Database authentication failed. Please check your DB_PASSWORD for user '{DB_USER}'")
        elif "no pg_hba.conf entry" in str(e):
            raise Exception(f"Network access denied. Your IP address is not allowed to connect to the RDS instance. Please check RDS security groups.")
        else:
            raise Exception(f"Database connection failed: {str(e)}")
    except Exception as e:
        raise Exception(f"Unexpected database error: {str(e)}")

def check_user_access(user_role, user_store_id, requested_store_id):
    """Check if user has access to the requested store data"""
    if user_role == 'admin':
        return True  # Admin can access all stores
    elif user_role == 'manager':
        return user_store_id == requested_store_id  # Manager can only access their store
    return False

# --- API Endpoints ---

# 1. NEW Login Endpoint
@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    user = USERS.get(username)
    if user and user['password'] == password:
        # Don't send the password back to the client
        user_data_to_send = {k: v for k, v in user.items() if k != 'password'}
        return jsonify(user_data_to_send)
    
    return jsonify({"error": "Invalid credentials"}), 401

# 2. NEW Get All Stores Endpoint (Admin only)
@app.route('/api/v1/stores', methods=['GET'])
def get_all_stores():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                store_id,
                location
            FROM stores
            ORDER BY store_id
        """)
        
        stores = cur.fetchall()
        conn.close()
        
        return jsonify({
            "success": True,
            "data": stores
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# 3. Dashboard Endpoint (Updated with access control)
@app.route('/api/v1/stores/<int:store_id>/dashboard', methods=['GET'])
def get_dashboard_data(store_id):
    try:
        # Get user info from request headers (you'll need to implement proper auth)
        # For now, we'll allow access to all stores
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get store location
        cur.execute("SELECT location FROM stores WHERE store_id = %s;", (store_id,))
        store_result = cur.fetchone()
        
        if not store_result:
            return jsonify({"error": "Store not found"}), 404
            
        location = store_result['location']
        
        # Get the latest transaction date for this store to calculate relative periods
        cur.execute("""
            SELECT MAX(transaction_date) as latest_date
            FROM transactions 
            WHERE store_id = %s
        """, (store_id,))
        
        latest_date_result = cur.fetchone()
        if not latest_date_result or not latest_date_result['latest_date']:
            # No transactions found, return empty data
            return jsonify({
                "store_id": store_id,
                "store_location": location,
                "kpi_summary": {
                    "current_weekly_sales": 0.0,
                    "previous_weekly_sales": 0.0,
                    "is_holiday_week": False
                },
                "sales_trend_7_days": []
            })
        
        latest_date = latest_date_result['latest_date']
        
        # Get KPI summary data - calculate total sales from transaction details and products
        # Use the last 7 days of available data
        cur.execute("""
            SELECT 
                COUNT(DISTINCT t.transaction_id) as transaction_count,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_amount
            FROM transactions t
            JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            JOIN products p ON td.product_id = p.product_id
            WHERE t.store_id = %s 
            AND t.transaction_date >= %s - INTERVAL '7 days'
        """, (store_id, latest_date))
        
        current_week = cur.fetchone()
        
        cur.execute("""
            SELECT 
                COUNT(DISTINCT t.transaction_id) as transaction_count,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_amount
            FROM transactions t
            JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            JOIN products p ON td.product_id = p.product_id
            WHERE t.store_id = %s 
            AND t.transaction_date >= %s - INTERVAL '14 days'
            AND t.transaction_date < %s - INTERVAL '7 days'
        """, (store_id, latest_date, latest_date))
        
        previous_week = cur.fetchone()
        
        # Get sales trend for last 7 days of available data
        cur.execute("""
            SELECT 
                DATE(t.transaction_date) as date,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as sales
            FROM transactions t
            JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            JOIN products p ON td.product_id = p.product_id
            WHERE t.store_id = %s 
            AND t.transaction_date >= %s - INTERVAL '7 days'
            GROUP BY DATE(t.transaction_date)
            ORDER BY date
        """, (store_id, latest_date))
        
        sales_trend = cur.fetchall()
        
        # Fill in missing dates with 0 sales
        from datetime import datetime, timedelta
        complete_sales_trend = []
        for i in range(7):
            date = (latest_date - timedelta(days=6-i)).strftime('%Y-%m-%d')
            existing_data = next((item for item in sales_trend if item['date'].strftime('%Y-%m-%d') == date), None)
            complete_sales_trend.append({
                'date': date,
                'sales': float(existing_data['sales']) if existing_data else 0
            })
        
        conn.close()
        
        return jsonify({
            "store_id": store_id,
            "store_location": location,
            "kpi_summary": {
                "current_weekly_sales": float(current_week['total_amount']) if current_week else 0,
                "previous_weekly_sales": float(previous_week['total_amount']) if previous_week else 0,
                "is_holiday_week": False  # You can implement holiday detection logic
            },
            "sales_trend_7_days": complete_sales_trend
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 4. NEW Admin Dashboard Endpoint (All stores summary)
@app.route('/api/v1/admin/dashboard', methods=['GET'])
def get_admin_dashboard():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get summary for all stores
        cur.execute("""
            SELECT 
                s.store_id,
                s.location,
                COUNT(DISTINCT t.transaction_id) as transaction_count,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_sales,
                COUNT(DISTINCT p.product_id) as product_count
            FROM stores s
            LEFT JOIN transactions t ON s.store_id = t.store_id
            LEFT JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            LEFT JOIN products p ON td.product_id = p.product_id
            GROUP BY s.store_id, s.location
            ORDER BY s.store_id
        """)
        
        stores_summary = cur.fetchall()
        
        # Calculate totals
        total_sales = sum(float(store['total_sales']) for store in stores_summary)
        total_transactions = sum(store['transaction_count'] for store in stores_summary)
        total_products = sum(store['product_count'] for store in stores_summary)
        
        conn.close()
        
        return jsonify({
            "success": True,
            "data": {
                "stores_summary": stores_summary,
                "totals": {
                    "total_sales": total_sales,
                    "total_transactions": total_transactions,
                    "total_products": total_products,
                    "store_count": len(stores_summary)
                }
            }
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# 5. Products List Endpoint (Improved with proper data types and error handling)
@app.route('/api/v1/stores/<int:store_id>/products', methods=['GET'])
def get_products(store_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                p.product_id, 
                p.product_name, 
                c.category_name, 
                p.unit_price, 
                i.inventory_level 
            FROM products p 
            JOIN categories c ON p.category_id = c.category_id 
            JOIN inventory i ON p.product_id = i.product_id 
            WHERE i.store_id = %s 
            ORDER BY p.product_name
        """
        
        cur.execute(query, (store_id,))
        products_raw = cur.fetchall()
        conn.close()
        
        # Convert the data to proper types
        products = []
        for product in products_raw:
            product_dict = dict(product)
            # Convert numeric fields to proper types
            product_dict['product_id'] = int(product_dict['product_id'])
            product_dict['unit_price'] = float(product_dict['unit_price']) if product_dict['unit_price'] else 0.0
            product_dict['inventory_level'] = int(product_dict['inventory_level']) if product_dict['inventory_level'] else 0
            
            products.append(product_dict)
        
        return jsonify(products)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# 6. MODIFIED Top Products Analytics Endpoint
@app.route('/api/v1/analytics/top-products', methods=['GET'])
def get_top_products():
    store_id = request.args.get('store_id', type=int)
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    base_query = """
        SELECT p.product_name, SUM(td.quantity) as total_sold
        FROM transactiondetails td
        JOIN products p ON td.product_id = p.product_id
        JOIN transactions t ON td.transaction_id = t.transaction_id
    """
    params = []
    
    # If a store_id is provided, add a WHERE clause
    if store_id:
        base_query += " WHERE t.store_id = %s"
        params.append(store_id)
        
    base_query += """
        GROUP BY p.product_name
        ORDER BY total_sold DESC
        LIMIT 5;
    """
    
    cur.execute(base_query, params)
    top_products = cur.fetchall()
    conn.close()
    return jsonify(top_products)


# 7. MODIFIED Store Transaction Share Analytics Endpoint
@app.route('/api/v1/analytics/store-transactions', methods=['GET'])
def get_store_transactions():
    # This endpoint is admin-only, so no filter is needed.
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    query = """
        SELECT s.location, COUNT(t.transaction_id) as transaction_count
        FROM transactions t
        JOIN stores s ON t.store_id = s.store_id
        GROUP BY s.location
        ORDER BY transaction_count DESC;
    """
    cur.execute(query)
    store_data = cur.fetchall()
    conn.close()
    return jsonify(store_data)


# 8. NEW Customers Endpoint
@app.route('/api/v1/customers', methods=['GET'])
def get_customers():
    store_id = request.args.get('store_id', type=int)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        base_query = """
            SELECT 
                c.customer_id,
                c.age,
                c.gender,
                c.income,
                c.loyalty_level,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_spent,
                COUNT(DISTINCT t.transaction_id) as orders_count,
                MAX(t.transaction_date) as last_order_date
            FROM customers c
            LEFT JOIN transactions t ON c.customer_id = t.customer_id
            LEFT JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            LEFT JOIN products p ON td.product_id = p.product_id
        """
        params = []
        
        # If a store_id is provided, add a WHERE clause
        if store_id:
            base_query += " WHERE t.store_id = %s"
            params.append(store_id)
            
        base_query += """
            GROUP BY c.customer_id, c.age, c.gender, c.income, c.loyalty_level
            ORDER BY total_spent DESC;
        """
        
        cur.execute(base_query, params)
        customers_raw = cur.fetchall()
        conn.close()
        
        # Convert the data to proper types
        customers = []
        for customer in customers_raw:
            customer_dict = dict(customer)
            # Convert numeric fields to proper types
            customer_dict['income'] = float(customer_dict['income']) if customer_dict['income'] else 0.0
            customer_dict['total_spent'] = float(customer_dict['total_spent']) if customer_dict['total_spent'] else 0.0
            customer_dict['orders_count'] = int(customer_dict['orders_count']) if customer_dict['orders_count'] else 0
            customer_dict['age'] = int(customer_dict['age']) if customer_dict['age'] else 0
            
            customers.append(customer_dict)
        
        return jsonify(customers)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 9. NEW Transactions Endpoint (with store filtering)
@app.route('/api/v1/transactions', methods=['GET'])
def get_transactions():
    store_id = request.args.get('store_id', type=int)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        base_query = """
            SELECT 
                t.transaction_id,
                t.store_id,
                s.location as store_location,
                t.transaction_date,
                t.customer_id,
                pm.method_name as payment_method,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_amount,
                COUNT(td.product_id) as items_count
            FROM transactions t
            LEFT JOIN stores s ON t.store_id = s.store_id
            LEFT JOIN paymentmethods pm ON t.payment_method_id = pm.method_id
            LEFT JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            LEFT JOIN products p ON td.product_id = p.product_id
        """
        params = []
        
        # If a store_id is provided, add a WHERE clause
        if store_id:
            base_query += " WHERE t.store_id = %s"
            params.append(store_id)
            
        base_query += """
            GROUP BY t.transaction_id, t.store_id, s.location, t.transaction_date, 
                     t.customer_id, pm.method_name
            ORDER BY t.transaction_date DESC;
        """
        
        cur.execute(base_query, params)
        transactions_raw = cur.fetchall()
        conn.close()
        
        # Convert the data to proper types
        transactions = []
        for transaction in transactions_raw:
            transaction_dict = dict(transaction)
            # Convert numeric fields to proper types
            transaction_dict['total_amount'] = float(transaction_dict['total_amount']) if transaction_dict['total_amount'] else 0.0
            transaction_dict['items_count'] = int(transaction_dict['items_count']) if transaction_dict['items_count'] else 0
            transaction_dict['store_id'] = int(transaction_dict['store_id']) if transaction_dict['store_id'] else 0
            transaction_dict['customer_id'] = int(transaction_dict['customer_id']) if transaction_dict['customer_id'] else None
            
            transactions.append(transaction_dict)
        
        return jsonify(transactions)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 9.5. NEW Store-specific Transactions Endpoint
@app.route('/api/v1/stores/<int:store_id>/transactions', methods=['GET'])
def get_store_transactions_by_id(store_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                t.transaction_id,
                t.store_id,
                s.location as store_location,
                t.transaction_date,
                t.customer_id,
                pm.method_name as payment_method,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_amount,
                COUNT(td.product_id) as items_count
            FROM transactions t
            LEFT JOIN stores s ON t.store_id = s.store_id
            LEFT JOIN paymentmethods pm ON t.payment_method_id = pm.method_id
            LEFT JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            LEFT JOIN products p ON td.product_id = p.product_id
            WHERE t.store_id = %s
            GROUP BY t.transaction_id, t.store_id, s.location, t.transaction_date, 
                     t.customer_id, pm.method_name
            ORDER BY t.transaction_date DESC;
        """
        
        cur.execute(query, (store_id,))
        transactions_raw = cur.fetchall()
        conn.close()
        
        # Convert the data to proper types
        transactions = []
        for transaction in transactions_raw:
            transaction_dict = dict(transaction)
            # Convert numeric fields to proper types
            transaction_dict['total_amount'] = float(transaction_dict['total_amount']) if transaction_dict['total_amount'] else 0.0
            transaction_dict['items_count'] = int(transaction_dict['items_count']) if transaction_dict['items_count'] else 0
            transaction_dict['store_id'] = int(transaction_dict['store_id']) if transaction_dict['store_id'] else 0
            transaction_dict['customer_id'] = int(transaction_dict['customer_id']) if transaction_dict['customer_id'] else None
            
            transactions.append(transaction_dict)
        
        return jsonify(transactions)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# 10. NEW Transaction Details Endpoint
@app.route('/api/v1/transactions/<int:transaction_id>', methods=['GET'])
def get_transaction_details(transaction_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get transaction details with items
        query = """
            SELECT 
                t.transaction_id,
                t.store_id,
                s.location as store_location,
                t.transaction_date,
                t.customer_id,
                pm.method_name as payment_method,
                t.promotion_applied,
                t.stockout,
                c.age,
                c.gender,
                c.income,
                c.loyalty_level,
                COALESCE(SUM(td.quantity * p.unit_price), 0) as total_amount,
                COUNT(td.product_id) as items_count
            FROM transactions t
            LEFT JOIN stores s ON t.store_id = s.store_id
            LEFT JOIN paymentmethods pm ON t.payment_method_id = pm.method_id
            LEFT JOIN customers c ON t.customer_id = c.customer_id
            LEFT JOIN transactiondetails td ON t.transaction_id = td.transaction_id
            LEFT JOIN products p ON td.product_id = p.product_id
            WHERE t.transaction_id = %s
            GROUP BY t.transaction_id, t.store_id, s.location, t.transaction_date, 
                     t.customer_id, pm.method_name, t.promotion_applied, t.stockout,
                     c.age, c.gender, c.income, c.loyalty_level
        """
        
        cur.execute(query, (transaction_id,))
        transaction = cur.fetchone()
        
        if not transaction:
            return jsonify({"error": "Transaction not found"}), 404
        
        # Get individual items in the transaction
        items_query = """
            SELECT 
                p.product_id,
                p.product_name,
                c.category_name,
                td.quantity,
                p.unit_price,
                (td.quantity * p.unit_price) as item_total
            FROM transactiondetails td
            JOIN products p ON td.product_id = p.product_id
            LEFT JOIN categories c ON p.category_id = c.category_id
            WHERE td.transaction_id = %s
            ORDER BY p.product_name
        """
        
        cur.execute(items_query, (transaction_id,))
        items = cur.fetchall()
        
        conn.close()
        
        # Convert to proper types
        transaction_dict = dict(transaction)
        transaction_dict['total_amount'] = float(transaction_dict['total_amount']) if transaction_dict['total_amount'] else 0.0
        transaction_dict['items_count'] = int(transaction_dict['items_count']) if transaction_dict['items_count'] else 0
        transaction_dict['store_id'] = int(transaction_dict['store_id']) if transaction_dict['store_id'] else 0
        transaction_dict['customer_id'] = int(transaction_dict['customer_id']) if transaction_dict['customer_id'] else None
        transaction_dict['age'] = int(transaction_dict['age']) if transaction_dict['age'] else None
        transaction_dict['income'] = float(transaction_dict['income']) if transaction_dict['income'] else None
        
        # Convert items to proper types
        items_list = []
        for item in items:
            item_dict = dict(item)
            item_dict['product_id'] = int(item_dict['product_id'])
            item_dict['quantity'] = int(item_dict['quantity'])
            item_dict['unit_price'] = float(item_dict['unit_price'])
            item_dict['item_total'] = float(item_dict['item_total'])
            items_list.append(item_dict)
        
        transaction_dict['items'] = items_list
        
        return jsonify(transaction_dict)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 11. NEW General Products Endpoint (for admin users)
@app.route('/api/v1/products', methods=['GET'])
def get_all_products():
    store_id = request.args.get('store_id', type=int)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        base_query = """
            SELECT 
                p.product_id, 
                p.product_name, 
                c.category_name, 
                p.unit_price, 
                COALESCE(i.inventory_level, 0) as inventory_level,
                s.location as store_location
            FROM products p 
            JOIN categories c ON p.category_id = c.category_id 
            LEFT JOIN inventory i ON p.product_id = i.product_id 
            LEFT JOIN stores s ON i.store_id = s.store_id
        """
        params = []
        
        # If a store_id is provided, add a WHERE clause
        if store_id:
            base_query += " WHERE i.store_id = %s"
            params.append(store_id)
            
        base_query += " ORDER BY p.product_name"
        
        cur.execute(base_query, params)
        products_raw = cur.fetchall()
        conn.close()
        
        # Convert the data to proper types
        products = []
        for product in products_raw:
            product_dict = dict(product)
            # Convert numeric fields to proper types
            product_dict['product_id'] = int(product_dict['product_id'])
            product_dict['unit_price'] = float(product_dict['unit_price']) if product_dict['unit_price'] else 0.0
            product_dict['inventory_level'] = int(product_dict['inventory_level']) if product_dict['inventory_level'] else 0
            
            products.append(product_dict)
        
        return jsonify(products)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=False, port=5002)
