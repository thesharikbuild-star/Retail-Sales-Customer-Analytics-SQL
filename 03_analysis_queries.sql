-- ============================================================
-- PROJECT: Retail Sales & Customer Analytics
-- FILE: 03_analysis_queries.sql
-- PURPOSE: Business questions solved with SQL
-- DIALECT: Written and tested on SQLite 3.45. Every query here
--          runs as-is on SQLite.
--          PostgreSQL/MySQL may require dialect-specific changes,
--          particularly for date functions.
--
-- NOTE ON "REVENUE":
-- Gross revenue includes Completed + Returned orders.
-- Cancelled orders are excluded.
-- Q16 reports net revenue collected using successful payments from
-- Completed orders only, so Returned orders are excluded there.
-- ============================================================


-- ------------------------------------------------------------
-- Q1. TOTAL GROSS REVENUE (all-time, Completed + Returned)
-- Concepts: JOIN, WHERE, aggregate SUM
-- ------------------------------------------------------------
SELECT
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled';


-- ------------------------------------------------------------
-- Q2. MONTHLY REVENUE
-- Concepts: GROUP BY, date functions, ORDER BY
-- Postgres:  DATE_TRUNC('month', o.order_date)  -- returns a DATE
-- MySQL:     DATE_FORMAT(o.order_date, '%Y-%m')
-- ------------------------------------------------------------
SELECT
    strftime('%Y-%m', o.order_date) AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue,
    COUNT(DISTINCT o.order_id) AS num_orders
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY order_month
ORDER BY order_month;


-- ------------------------------------------------------------
-- Q3. TOP 10 PRODUCTS BY REVENUE
-- Concepts: JOIN, GROUP BY, ORDER BY, LIMIT
-- ------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS product_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status <> 'Cancelled'
GROUP BY p.product_id, p.product_name
ORDER BY product_revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q4. HIGHEST-VALUE CUSTOMERS (Top 10 by lifetime spend)
-- Concepts: JOIN across 3 tables, GROUP BY, ORDER BY, LIMIT
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    c.region,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS lifetime_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY c.customer_id, c.customer_name, c.region
ORDER BY lifetime_value DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q5. REPEAT CUSTOMERS (customers with more than 1 completed order)
-- Concepts: GROUP BY, HAVING
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY total_orders DESC;

-- 5b. Repeat-customer RATE (what % of all customers are repeat buyers)
-- Concepts: CTE, subquery, CASE WHEN
WITH customer_order_counts AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    LEFT JOIN orders o
        ON o.customer_id = c.customer_id AND o.order_status = 'Completed'
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2
    ) AS repeat_customer_pct
FROM customer_order_counts;


-- ------------------------------------------------------------
-- Q6. AVERAGE ORDER VALUE (AOV)
-- Concepts: subquery, aggregate
-- ------------------------------------------------------------
SELECT
    ROUND(SUM(oi.quantity * oi.unit_price) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled';

-- 6b. AOV per month (trend view)
SELECT
    strftime('%Y-%m', o.order_date) AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY order_month
ORDER BY order_month;


-- ------------------------------------------------------------
-- Q7. CATEGORY-WISE PERFORMANCE
-- Concepts: multi-table JOIN, GROUP BY, window function for % share
-- ------------------------------------------------------------
SELECT
    cat.category_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS category_revenue,
    ROUND(
        100.0 * SUM(oi.quantity * oi.unit_price)
        / SUM(SUM(oi.quantity * oi.unit_price)) OVER (), 2
    ) AS pct_of_total_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
WHERE o.order_status <> 'Cancelled'
GROUP BY cat.category_name
ORDER BY category_revenue DESC;


-- ------------------------------------------------------------
-- Q8. REGION-WISE SALES
-- Concepts: JOIN, GROUP BY, ORDER BY
-- ------------------------------------------------------------
SELECT
    c.region,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_id) AS unique_customers,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS region_revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY c.region
ORDER BY region_revenue DESC;


-- ------------------------------------------------------------
-- Q9. MONTH-OVER-MONTH (MoM) REVENUE GROWTH
-- Concepts: CTE, WINDOW FUNCTION -> LAG(), CASE WHEN (guard div-by-zero)
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date) AS order_month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'Cancelled'
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
    CASE
        WHEN LAG(revenue) OVER (ORDER BY order_month) IS NULL THEN NULL
        WHEN LAG(revenue) OVER (ORDER BY order_month) = 0 THEN NULL
        ELSE ROUND(
            100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
            / LAG(revenue) OVER (ORDER BY order_month), 2
        )
    END AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


-- ------------------------------------------------------------
-- Q10. CUSTOMERS WHO HAVEN'T PURCHASED RECENTLY (churn risk / win-back list)
-- Concepts: CTE, subquery, date functions, LEFT JOIN
-- "Recently" = within the last 90 days of the most recent order date
-- in the dataset (stand-in for "today" so results are reproducible).
-- ------------------------------------------------------------
WITH last_order AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),
dataset_today AS (
    SELECT MAX(order_date) AS today FROM orders
)
SELECT
    c.customer_id,
    c.customer_name,
    lo.last_order_date,
    CAST(julianday((SELECT today FROM dataset_today)) - julianday(lo.last_order_date) AS INTEGER) AS days_since_last_order
FROM customers c
JOIN last_order lo ON lo.customer_id = c.customer_id
WHERE julianday((SELECT today FROM dataset_today)) - julianday(lo.last_order_date) > 90
ORDER BY days_since_last_order DESC;

-- 10b. Customers with ZERO orders ever (never purchased)
-- Concepts: LEFT JOIN + IS NULL (anti-join pattern)
SELECT
    c.customer_id,
    c.customer_name,
    c.signup_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;


-- ------------------------------------------------------------
-- Q11. BEST-PERFORMING PRODUCT PER CATEGORY
-- Concepts: WINDOW FUNCTIONS -> ROW_NUMBER(), RANK(), PARTITION BY
-- ------------------------------------------------------------
WITH product_revenue AS (
    SELECT
        cat.category_name,
        p.product_id,
        p.product_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.order_status <> 'Cancelled'
    GROUP BY cat.category_name, p.product_id, p.product_name
),
ranked AS (
    SELECT
        category_name,
        product_name,
        ROUND(revenue, 2) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS rn,
        RANK()       OVER (PARTITION BY category_name ORDER BY revenue DESC) AS rnk
    FROM product_revenue
)
SELECT category_name, product_name, revenue, rnk AS rank_in_category
FROM ranked
WHERE rnk = 1
ORDER BY revenue DESC;

-- NOTE on ROW_NUMBER() vs RANK():
-- ROW_NUMBER() always gives unique 1,2,3... even on ties.
-- RANK() gives the same rank to tied rows and then skips
-- (e.g. 1,2,2,4). The final filter uses RANK() = 1 so every
-- co-leading product is retained when there is a revenue tie.


-- ------------------------------------------------------------
-- Q12. REVENUE CONTRIBUTION % PER PRODUCT (of total revenue)
-- Concepts: WINDOW FUNCTION -> SUM() OVER() for running total share
-- ------------------------------------------------------------
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status <> 'Cancelled'
    GROUP BY p.product_id, p.product_name
)
SELECT
    product_name,
    ROUND(revenue, 2) AS revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total_revenue,
    ROUND(
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(revenue) OVER (), 2
    ) AS cumulative_pct   -- classic "80/20" Pareto view
FROM product_revenue
ORDER BY revenue DESC;


-- ------------------------------------------------------------
-- Q13. CUSTOMER SEGMENTATION BY SPEND (CASE WHEN bucketing)
-- Concepts: CASE WHEN, CTE, GROUP BY
-- ------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(oi.quantity * oi.unit_price) AS lifetime_value
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status <> 'Cancelled'
    GROUP BY c.customer_id, c.customer_name
)
SELECT
    customer_id,
    customer_name,
    ROUND(lifetime_value, 2) AS lifetime_value,
    CASE
        WHEN lifetime_value >= 20000 THEN 'High Value'
        WHEN lifetime_value >= 8000  THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_spend
ORDER BY lifetime_value DESC;


-- ------------------------------------------------------------
-- Q14. CUSTOMERS WHOSE AVERAGE ORDER VALUE IS ABOVE THE OVERALL AOV
-- Concepts: independent subquery, GROUP BY, HAVING
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    c.customer_name,
    ROUND(SUM(oi.quantity * oi.unit_price) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS customer_aov
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY c.customer_id, c.customer_name
HAVING (SUM(oi.quantity * oi.unit_price) * 1.0 / COUNT(DISTINCT o.order_id)) >
    (
        -- overall AOV, computed as an independent subquery
        SELECT SUM(oi2.quantity * oi2.unit_price) * 1.0 / COUNT(DISTINCT o2.order_id)
        FROM order_items oi2
        JOIN orders o2 ON o2.order_id = oi2.order_id
        WHERE o2.order_status <> 'Cancelled'
    )
ORDER BY customer_aov DESC;


-- ------------------------------------------------------------
-- Q15. DAYS BETWEEN A CUSTOMER'S CONSECUTIVE ORDERS (purchase cadence)
-- Concepts: WINDOW FUNCTIONS -> LAG() and LEAD(), date arithmetic
-- ------------------------------------------------------------
SELECT
    customer_id,
    order_id,
    order_date,
    LAG(order_date)  OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date,
    CAST(julianday(order_date) -
         julianday(LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date))
         AS INTEGER) AS days_since_previous_order,
    LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_date
FROM orders
WHERE order_status = 'Completed'
ORDER BY customer_id, order_date;


-- ------------------------------------------------------------
-- Q16. NET REVENUE (excludes returned/refunded orders too, not just cancelled)
-- Concepts: JOIN with payments, WHERE with multiple conditions
-- Useful because Q1's "gross revenue" still counted Returned orders.
-- ------------------------------------------------------------
SELECT
    ROUND(SUM(p.amount), 2) AS net_revenue_collected
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_status = 'Success'
  AND o.order_status = 'Completed';


-- ------------------------------------------------------------
-- Q17. PAYMENT METHOD MIX
-- Concepts: GROUP BY, CASE WHEN, percentage share
-- ------------------------------------------------------------
SELECT
    payment_method,
    COUNT(*) AS num_payments,
    ROUND(SUM(amount), 2) AS total_amount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_transactions
FROM payments
WHERE payment_status = 'Success'
GROUP BY payment_method
ORDER BY total_amount DESC;
