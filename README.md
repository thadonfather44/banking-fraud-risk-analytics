🏦 Banking Fraud Risk Analytics Dashboard

📌 Project Overview
This project analyzes customer transaction data to identify high-risk fraud patterns using SQL and Power BI. It simulates a real-world banking fraud detection workflow by transforming raw data into actionable insights.

The solution includes:
Data cleaning and transformation in SQL
Feature engineering for fraud detection
Risk classification logic
Interactive Power BI dashboard with DAX measures
  
 🛠️ Tools Used
MySQL (Data storage, cleaning, feature engineering)
Power BI (Visualization & dashboarding)
DAX (Measures & calculations)


🧠 Key Insights
High-risk customers show increased night-time activity
Large transactions are concentrated among a small group of users
Multiple locations and device usage correlate with higher risk

⚙️ Key Features
Data cleaning and transformation using SQL
Feature engineering for fraud detection
Risk classification (Low, Medium, High)
Interactive dashboard with drillthrough analysis
Behavioral analysis of transactions

🚀 How to Run
Load dataset into MySQL
Run SQL scripts in order
Connect Power BI to database
Open .pbix file



🗄️ SQL Implementation

1. Create Database
sql
CREATE DATABASE banking_fraud_db;
USE banking_fraud_db;

2. Create Raw Tables (Staging Layer)
CREATE TABLE customers_raw (
    customer_id INT,
    age INT,
    employment_status VARCHAR(50),
    income DECIMAL(10,2),
    account_open_date DATE
);

CREATE TABLE transactions_raw (
    transaction_id INT,
    customer_id INT,
    transaction_amount DECIMAL(12,2),
    transaction_type VARCHAR(50),
    transaction_time DATETIME,
    location VARCHAR(100),
    device_type VARCHAR(50)
);

3.Data Cleaning (Transformation Layer)
CREATE TABLE customers_clean AS
SELECT DISTINCT * FROM customers_raw;

CREATE TABLE transactions_clean AS
SELECT DISTINCT * FROM transactions_raw;

Handle Missing Values

Purpose: Ensure consistency and avoid null-related errors

SET @avg_income = (SELECT AVG(income) FROM customers_clean);

UPDATE customers_clean
SET income = @avg_income
WHERE income IS NULL;

UPDATE customers_clean
SET employment_status = 'Unknown'
WHERE employment_status IS NULL OR employment_status = '';

Clean Transactions
DELETE FROM transactions_clean
WHERE transaction_amount <= 0
   OR transaction_amount > 100000;

UPDATE transactions_clean
SET location = 'Unknown'
WHERE location IS NULL OR location = '';

UPDATE transactions_clean
SET device_type = 'Unknown'
WHERE device_type IS NULL OR device_type = '';

4. Feature Engineering

CREATE TABLE customer_features AS
SELECT 
    customer_id,
    COUNT(*) AS total_transactions,
    SUM(transaction_amount) AS total_spent,
    AVG(transaction_amount) AS avg_transaction,
    MAX(transaction_amount) AS max_transaction,

    SUM(CASE WHEN transaction_amount > 10000 THEN 1 ELSE 0 END) AS high_value_txns,

    SUM(CASE 
        WHEN HOUR(transaction_time) BETWEEN 0 AND 4 
        THEN 1 ELSE 0 
    END) AS night_txns,

    COUNT(DISTINCT location) AS unique_locations,
    COUNT(DISTINCT device_type) AS unique_devices

FROM transactions_clean
GROUP BY customer_id;

5. Enrich Features with Customer Data
CREATE TABLE customer_features_enriched AS
SELECT 
    c.customer_id,
    c.age,
    c.income,
    c.employment_status,
    c.account_open_date,
    f.*
FROM customers_clean c
LEFT JOIN customer_features f
ON c.customer_id = f.customer_id;

6. Risk Classification

CREATE TABLE customer_risk AS
SELECT *,
CASE 
    WHEN high_value_txns > 5 
         AND night_txns > 3 
         AND unique_locations > 3 
    THEN 'High Risk'

    WHEN high_value_txns > 3 
         OR night_txns > 2 
    THEN 'Medium Risk'

    ELSE 'Low Risk'
END AS risk_level
FROM customer_features_enriched;

📊 Power BI (DAX Measures)

Total Customers
Total Customers = DISTINCTCOUNT(customer_risk[customer_id])

Total Transactions
Total Transactions = COUNT(transactions_clean[transaction_id])

Total Transaction Value
Total Value = SUM(transactions_clean[transaction_amount])

Average Transaction Value
Avg Transaction = AVERAGE(transactions_clean[transaction_amount])

High Risk Customers
High Risk Customers = 
CALCULATE(
    DISTINCTCOUNT(customer_risk[customer_id]),
    customer_risk[risk_level] = "High Risk"
)

Medium Risk Customers
Medium Risk Customers = 
CALCULATE(
    DISTINCTCOUNT(customer_risk[customer_id]),
    customer_risk[risk_level] = "Medium Risk"
)

 Fraud Rate %
Fraud Rate % = 
DIVIDE(
    [High Risk Customers],
    [Total Customers],
    0
)

High Value Transactions
High Value Transactions = 
CALCULATE(
    COUNT(transactions_clean[transaction_id]),
    transactions_clean[transaction_amount] > 10000
)

Time Category (Calculated Column)
Time Category = 
IF(
    HOUR(transactions_clean[transaction_time]) >= 0 &&
    HOUR(transactions_clean[transaction_time]) <= 4,
    "Night",
    "Day"
)

Age Group (Calculated Column)
Age Group = 
SWITCH(
    TRUE(),
    customer_risk[age] < 25, "18-24",
    customer_risk[age] < 35, "25-34",
    customer_risk[age] < 50, "35-49",
    "50+"
)

Income Band (Calculated Column)
Income Band = 
SWITCH(
    TRUE(),
    customer_risk[income] < 10000, "Low Income",
    customer_risk[income] < 30000, "Middle Income",
    "High Income"
)

