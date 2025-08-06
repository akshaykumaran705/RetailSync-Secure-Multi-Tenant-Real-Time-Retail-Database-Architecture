-- Customers Table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    age INT,
    gender VARCHAR(10),
    income DECIMAL(10,2),
    loyalty_level VARCHAR(20)
);

-- Stores Table
CREATE TABLE Stores (
    store_id INT PRIMARY KEY,
    location VARCHAR(100)
);

-- Categories Table
CREATE TABLE Categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) UNIQUE
);

-- Products Table
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category_id INT,
    supplier_id INT,
    unit_price DECIMAL(10,2),
    reorder_point INT,
    reorder_quantity INT,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);


-- Weather Table
CREATE TABLE Weather (
    weather_id SERIAL PRIMARY KEY,
    weather_conditions VARCHAR(50)
);

-- PaymentMethods Table
CREATE TABLE PaymentMethods (
    method_id SERIAL PRIMARY KEY,
    method_name VARCHAR(50)
);

-- Promotions Table
CREATE TABLE Promotions (
    promotion_id SERIAL PRIMARY KEY,
    promotion_type VARCHAR(50)
);

-- Transactions Table
CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY,
    transaction_date TIMESTAMP,
    customer_id INT,
    store_id INT,
    payment_method_id INT,
    promotion_applied BOOLEAN,
    promotion_id INT,
    weather_id INT,
    stockout BOOLEAN,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES Stores(store_id),
    FOREIGN KEY (payment_method_id) REFERENCES PaymentMethods(method_id),
    FOREIGN KEY (promotion_id) REFERENCES Promotions(promotion_id),
    FOREIGN KEY (weather_id) REFERENCES Weather(weather_id)
);

-- TransactionDetails Table
CREATE TABLE TransactionDetails (
    transaction_id INT,
    product_id INT,
    quantity INT,
    PRIMARY KEY (transaction_id, product_id),
    FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- Inventory Table
CREATE TABLE Inventory (
    store_id INT,
    product_id INT,
    inventory_level INT,
    PRIMARY KEY (store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES Stores(store_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- PromotionApplications Table
CREATE TABLE PromotionApplications (
    transaction_id INT,
    promotion_id INT,
    PRIMARY KEY (transaction_id, promotion_id),
    FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id),
    FOREIGN KEY (promotion_id) REFERENCES Promotions(promotion_id)
);

-- DemandForecast Table (optional)
CREATE TABLE DemandForecast (
    forecast_date DATE NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    forecasted_demand INT,
    actual_demand INT,
    PRIMARY KEY (forecast_date, store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES Stores(store_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);





DROP TABLE IF EXISTS 
    TransactionDetails,
    PromotionApplications,
    Transactions,
    DemandForecast,
    Inventory,
    Products,
    Customers,
    Stores,
    PaymentMethods,
    Promotions,
    Weather,
	Categories
CASCADE;

