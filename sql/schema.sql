-- ============================================================
-- Sales Health Monitor — Database Schema
-- Creates the database, the sales table, and 4 analysis views
-- ============================================================

CREATE DATABASE IF NOT EXISTS sales_db;
USE sales_db;

-- ------------------------------------------------------------
-- Main table
-- order_id is the PRIMARY KEY, enforcing uniqueness at the DB
-- level (the source data had 80 duplicate order_ids removed
-- during the Python cleaning stage before this table is loaded).
-- ------------------------------------------------------------
CREATE TABLE sales (
    order_id VARCHAR(20) PRIMARY KEY,
    order_date DATE,
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    age DECIMAL(5,1),
    gender VARCHAR(10),
    region VARCHAR(20),
    city VARCHAR(50),
    product_category VARCHAR(50),
    product_name VARCHAR(100),
    quantity DECIMAL(6,1),
    unit_price DECIMAL(12,2),
    discount_pct DECIMAL(5,2),
    sales_amount DECIMAL(15,2),
    profit DECIMAL(15,2),
    shipping_cost DECIMAL(8,2),
    payment_method VARCHAR(30),
    customer_satisfaction DECIMAL(3,1),   -- NULL allowed: no fake ratings
    return_flag BOOLEAN,
    order_status VARCHAR(20),
    days_to_ship DECIMAL(6,1),            -- NULL allowed: orders that never shipped
    quantity_imputed BOOLEAN,
    discount_pct_imputed BOOLEAN,
    age_imputed BOOLEAN,
    feedback_given BOOLEAN,
    days_to_ship_imputed BOOLEAN,
    shipping_cost_imputed BOOLEAN,
    sales_amount_recalculated BOOLEAN,
    Month INT,
    Year INT,
    age_group VARCHAR(20),
    returned BOOLEAN
);

-- ------------------------------------------------------------
-- Views
-- ------------------------------------------------------------

-- Monthly revenue/profit rollup — feeds the trend chart
CREATE VIEW v_monthly_sales_summary AS
SELECT
    Year,
    Month,
    SUM(sales_amount) AS monthly_revenue,
    SUM(profit) AS monthly_profit,
    COUNT(*) AS order_count
FROM sales
GROUP BY Year, Month;

-- Revenue/profit/margin by product category
CREATE VIEW v_category_performance AS
SELECT
    product_category,
    SUM(sales_amount) AS revenue,
    SUM(profit) AS profit,
    SUM(profit) / SUM(sales_amount) * 100 AS margin_pct,
    COUNT(*) AS orders,
    AVG(customer_satisfaction) AS avg_satisfaction
FROM sales
GROUP BY product_category;

-- Revenue/profit/margin by region
CREATE VIEW v_region_performance AS
SELECT
    region,
    SUM(sales_amount) AS revenue,
    SUM(profit) AS profit,
    SUM(profit) / SUM(sales_amount) * 100 AS margin_pct,
    COUNT(*) AS orders
FROM sales
GROUP BY region;

-- Business-rule anomaly flags: loss-making orders, contradictory
-- discount/margin combinations, and unusually long shipping times
CREATE VIEW v_anomalies AS
SELECT
    order_id,
    order_date,
    profit,
    sales_amount,
    discount_pct,
    days_to_ship,
    CASE
        WHEN profit < 0 THEN 'Loss-making order'
        WHEN discount_pct > 0.35 AND (profit / sales_amount) > 0.3 THEN 'High discount + high margin'
        WHEN days_to_ship > 15 THEN 'Unusually long shipping time'
    END AS anomaly_type
FROM sales
WHERE profit < 0
   OR (discount_pct > 0.35 AND (profit / sales_amount) > 0.3)
   OR days_to_ship > 15;
