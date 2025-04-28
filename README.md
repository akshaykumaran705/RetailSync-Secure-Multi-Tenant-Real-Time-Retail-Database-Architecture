# Secure and Scalable Multi-Tenant Retail Database Architecture Using PostgreSQL, Kafka, and MongoDB

---

# 📖 Introduction

This project builds a **secure, scalable, multi-tenant retail database system**. It is designed for a SaaS environment where multiple stores operate independently within a single shared database. The project incorporates:
- **PostgreSQL** as the OLTP database for transactional integrity
- **Row-Level Security (RLS)** and **RBAC** for strict data access control
- **Kafka and Debezium** for **real-time CDC replication** from PostgreSQL
- **MongoDB** as an analytics and fraud detection platform

Dataset: Cleaned Walmart retail transaction data.

---

# 🖼️ ERD and Architecture Diagrams

## 1. Normalized Database Design

![Database Design](images/WalmartERD-Database%20Design.jpg)

> This ERD illustrates a fully normalized relational schema with separate entity tables for Customers, Stores, Products, Promotions, and Weather, and transactional tables for Transactions and TransactionDetails.

## 2. Final ERD after Full Normalization

![Final ERD](images/WalmartERD-Final.jpg)

> Additional normalization separates Categories and Suppliers, ensuring full BCNF compliance.

## 3. Replication Strategy Diagram

![Replication Strategy](images/WalmartERD-ReplicationStrategy.jpg)

> Red tables are replicated in real-time using Kafka + Debezium; Green tables are batch ETL-loaded into MongoDB.

---

# 🗄️ Schema Creation and Data Population

Based on the normalized ERD, tables were created in PostgreSQL with strict primary and foreign key constraints to maintain integrity. Master tables like Customers, Stores, Products, Promotions, Weather were created first.

Data was populated using a **Python ETL script**, which loaded the cleaned Walmart retail dataset into the PostgreSQL tables. Arrays and pandas dataframes were used for efficient bulk inserts.

---

# 🔄 Inventory Management with Triggers and Stored Procedures

Initially, a **Trigger Function** was created to automatically decrement the inventory level when a new TransactionDetail was inserted.

Later, a more robust **Stored Procedure** (`insert_transaction`) was developed:
- Inserts a new transaction into the Transactions table
- Loops through an array of product IDs and quantities
- Validates inventory availability
- Inserts into TransactionDetails safely, ensuring transactional atomicity

This automated inventory adjustment ensures OLTP integrity without manual updates.

---

# 🛡️ Implementing RLS and RBAC for Tenant Isolation

To ensure store-wise tenant isolation:

- **Indexes** were created on `store_id` in key tables (Transactions, Inventory, DemandForecast) to improve performance for tenant-specific queries.
- **RLS (Row-Level Security)** was enabled on Transactions, Inventory, and DemandForecast tables.
- **Policies** were defined so that each store_user role could only SELECT, INSERT, UPDATE, DELETE rows related to their store_id.
- **RBAC (Role-Based Access Control)** was implemented using PostgreSQL roles for each store (`store_user_1`, `store_user_2`, etc.) and an admin user.

This combination of indexing, RLS, and RBAC ensures secure and performant multi-tenant access.

---

# 🔗 Replication to MongoDB

## Step 1: Creating a Publication

A PostgreSQL publication `walmart_publication` was created, exposing all tables for logical replication.

```sql
CREATE PUBLICATION walmart_publication FOR ALL TABLES;
```

## Step 2: Batch ETL for Initial Load

All tables were batch-loaded into MongoDB using a **Python script**:
- Tables were extracted from PostgreSQL
- Documents were formatted for MongoDB
- Inserted into appropriate collections

## Step 3: Setting Up Real-Time Replication

**Kafka and Debezium** were set up locally:
- Kafka and Zookeeper running on localhost
- Debezium PostgreSQL Source Connector configured to listen to WAL changes and publish to Kafka topics.
- MongoDB Sink Connector configured to subscribe to Kafka topics and write into MongoDB collections.

This enables real-time replication of Transactions, Inventory, and TransactionDetails.

---

# 🐍 Kafka-Debezium-MongoDB Setup (Local)

Kafka, Debezium Connect, and MongoDB were all configured and run locally. The Debezium connector reads WAL logs from PostgreSQL, Kafka brokers the events, and the MongoDB Sink Connector applies them into MongoDB collections.

✅ PostgreSQL ➔ Debezium ➔ Kafka ➔ MongoDB (real-time streaming)

---

# 📦 Sample MongoDB Replication Output

Sample document inserted into `walmart_realtime.transactions`:

```json
{
  "transaction_id": 5001,
  "transaction_date": "2024-04-10T15:00:00Z",
  "customer_id": 1001,
  "store_id": 1,
  "payment_method_id": 1,
  "promotion_applied": false,
  "promotion_id": null,
  "weather_id": 1,
  "stockout": false
}
```

✅ Changes made in PostgreSQL are reflected within milliseconds in MongoDB.

---

# 📝 Conclusion

Through this project, we:
- Designed a fully normalized, scalable, multi-tenant OLTP retail database using PostgreSQL.
- Enforced strict tenant isolation using Row-Level Security and Role-Based Access Control.
- Implemented real-time replication from PostgreSQL to MongoDB using Kafka and Debezium.
- Enabled batch ETL for non-critical tables and live streaming for transactional tables.
- Demonstrated fraud detection and inventory analytics using MongoDB aggregation pipelines.

> 🎯 This project simulates a real-world, production-grade architecture for secure, scalable, real-time retail SaaS systems.

---

# 🚀 Ready for Presentation and GitHub Upload!
