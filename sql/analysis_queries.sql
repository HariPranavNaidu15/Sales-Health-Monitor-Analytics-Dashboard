-- ============================================================
-- Sales Health Monitor — Analysis Queries
-- KPI, trend, segmentation, and anomaly-detection queries used
-- to validate the dataset and build the Power BI dashboard.
-- Run against sales_db (see schema.sql).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Core revenue KPIs
-- profit_margin_pct is SUM(profit)/SUM(sales_amount), not
-- AVG(profit/sales_amount) — weights by order size so a tiny
-- high-margin order can't distort the overall margin figure.
-- ------------------------------------------------------------
SELECT
    ROUND(SUM(sales_amount), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(SUM(profit) / SUM(sales_amount) * 100, 2) AS profit_margin_pct,
    ROUND(AVG(sales_amount), 2) AS avg_order_value,
    COUNT(*) AS total_orders
FROM sales;

-- ------------------------------------------------------------
-- 2. Return rate, satisfaction, shipping KPIs
-- AVG() on customer_satisfaction / days_to_ship automatically
-- skips NULLs — these were deliberately left NULL rather than
-- imputed during cleaning, so the averages stay honest.
-- ------------------------------------------------------------
SELECT
    ROUND(AVG(returned) * 100, 2) AS return_rate_pct,
    ROUND(AVG(customer_satisfaction), 2) AS avg_satisfaction,
    ROUND(AVG(days_to_ship), 2) AS avg_days_to_ship
FROM sales;

-- ------------------------------------------------------------
-- 3. Monthly revenue trend
-- ------------------------------------------------------------
SELECT
    Year,
    Month,
    ROUND(SUM(sales_amount), 2) AS monthly_revenue,
    COUNT(*) AS order_count
FROM sales
GROUP BY Year, Month
ORDER BY Year, Month;

-- ------------------------------------------------------------
-- 4. Performance by product category
-- ------------------------------------------------------------
SELECT
    product_category,
    ROUND(SUM(sales_amount), 2) AS revenue,
    ROUND(SUM(profit), 2) AS profit,
    ROUND(SUM(profit) / SUM(sales_amount) * 100, 2) AS margin_pct,
    COUNT(*) AS orders,
    ROUND(AVG(customer_satisfaction), 2) AS avg_satisfaction
FROM sales
GROUP BY product_category
ORDER BY revenue DESC;

-- ------------------------------------------------------------
-- 5. Performance by region
-- ------------------------------------------------------------
SELECT
    region,
    ROUND(SUM(sales_amount), 2) AS revenue,
    ROUND(SUM(profit), 2) AS profit,
    ROUND(SUM(profit) / SUM(sales_amount) * 100, 2) AS margin_pct,
    COUNT(*) AS orders
FROM sales
GROUP BY region
ORDER BY revenue DESC;

-- ------------------------------------------------------------
-- 6. Statistical anomaly detection (z-score, window functions)
-- Flags orders more than 3 standard deviations from the mean
-- sales_amount. AVG()/STDDEV() OVER() compute table-wide stats
-- while keeping every row visible (unlike GROUP BY).
-- ------------------------------------------------------------
SELECT order_id, sales_amount, ROUND(z_score, 2) AS z_score
FROM (
    SELECT
        order_id,
        sales_amount,
        (sales_amount - AVG(sales_amount) OVER()) / STDDEV(sales_amount) OVER() AS z_score
    FROM sales
) AS scored
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

-- ------------------------------------------------------------
-- 7. Business-rule anomaly detection (detailed row list)
-- See v_anomalies in schema.sql for the reusable view version.
-- ------------------------------------------------------------
SELECT
    order_id,
    profit,
    sales_amount,
    discount_pct,
    days_to_ship,
    CASE
        WHEN profit < 0 THEN 'Loss-making order'
        WHEN discount_pct > 0.35 AND (profit / sales_amount) > 0.3 THEN 'High discount + high margin (check pricing)'
        WHEN days_to_ship > 15 THEN 'Unusually long shipping time'
    END AS anomaly_type
FROM sales
WHERE profit < 0
   OR (discount_pct > 0.35 AND (profit / sales_amount) > 0.3)
   OR days_to_ship > 15;

-- ------------------------------------------------------------
-- 8. Business-rule anomaly breakdown (counts by type)
-- ------------------------------------------------------------
SELECT anomaly_type, COUNT(*) AS count
FROM (
    SELECT
        order_id,
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
       OR days_to_ship > 15
) AS flagged
GROUP BY anomaly_type;
