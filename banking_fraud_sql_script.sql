-- =========================================
-- Banking Fraud Risk Analytics Project
-- Full SQL Script
-- =========================================

-- 1. DATABASE SETUP
CREATE DATABASE IF NOT EXISTS banking_fraud_db;
USE banking_fraud_db;

-- =========================================
-- 2. RAW TABLES (STAGING)
-- =========================================

CREATE TABLE IF NOT EXISTS customers_raw (
    customer_id INT,
    age INT,
    employment_status VARCHAR(50),
    income DECIMAL(10,2),
    account_open_date DATE
);

CREATE TABLE IF NOT EXISTS transactions_raw (
    transaction_id INT,
    customer_id INT,
    transaction_amount DECIMAL(12,2),
    transaction_type VARCHAR(50),
    transaction_time DATETIME,
    location VARCHAR(100),
    device_type VARCHAR(50)
);

-- =========================================
-- 3. CLEANING LAYER
-- =========================================

DROP TABLE IF EXISTS customers_clean;
CREATE TABLE customers_clean AS
SELECT DISTINCT * FROM customers_raw;

DROP TABLE IF EXISTS transactions_clean;
CREATE TABLE transactions_clean AS
SELECT DISTINCT * FROM transactions_raw;

-- Handle missing income
SET @avg_income = (SELECT AVG(income) FROM customers_clean);

UPDATE customers_clean
SET income = @avg_income
WHERE income IS NULL;

-- Handle missing employment status
UPDATE customers_clean
SET employment_status = 'Unknown'
WHERE employment_status IS NULL OR employment_status = '';

-- Remove invalid transactions
DELETE FROM transactions_clean
WHERE transaction_amount <= 0
   OR transaction_amount > 100000;

-- Fix missing categorical values
UPDATE transactions_clean
SET location = 'Unknown'
WHERE location IS NULL OR location = '';

UPDATE transactions_clean
SET device_type = 'Unknown'
WHERE device_type IS NULL OR device_type = '';

-- =========================================
-- 4. FEATURE ENGINEERING
-- =========================================

DROP TABLE IF EXISTS customer_features;

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

-- =========================================
-- 5. ENRICHMENT
-- =========================================

DROP TABLE IF EXISTS customer_features_enriched;

CREATE TABLE customer_features_enriched AS
SELECT 
    c.customer_id,
    c.age,
    c.income,
    c.employment_status,
    c.account_open_date,

    f.total_transactions,
    f.total_spent,
    f.avg_transaction,
    f.max_transaction,
    f.high_value_txns,
    f.night_txns,
    f.unique_locations,
    f.unique_devices

FROM customers_clean c
LEFT JOIN customer_features f
ON c.customer_id = f.customer_id;

-- =========================================
-- 6. RISK CLASSIFICATION
-- =========================================

DROP TABLE IF EXISTS customer_risk;

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

-- =========================================
-- 7. VALIDATION
-- =========================================

SELECT risk_level, COUNT(*) 
FROM customer_risk
GROUP BY risk_level;

SELECT COUNT(*) AS customers_count FROM customers_clean;
SELECT COUNT(*) AS transactions_count FROM transactions_clean;
