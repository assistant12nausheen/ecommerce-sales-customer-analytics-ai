-- =============================================================================
-- basic_analysis.sql
-- =============================================================================
-- Project : E-Commerce Sales & Customer Analytics with AI
-- Phase   : 6 -- SQL Business Analysis
-- Database: olist_ecommerce
--
-- PURPOSE
-- -------
-- Beginner-friendly SQL queries that answer common business questions
-- about the Olist e-commerce marketplace.
--
-- HOW TO RUN
-- ----------
-- Option 1 (whole file at once):
--   mysql -u root -p olist_ecommerce < sql/basic_analysis.sql
--
-- Option 2 (one query at a time in MySQL Workbench or DBeaver):
--   Copy any single query block and execute it.
--
-- CONCEPTS USED
-- -------------
--   SELECT       -- choose which columns to return
--   FROM         -- which table to read
--   JOIN         -- combine rows from two tables using a shared column
--   WHERE        -- filter rows before grouping
--   GROUP BY     -- group rows with the same value to apply aggregates
--   ORDER BY     -- sort the result
--   LIMIT        -- return only the top N rows
--   COUNT()      -- count rows
--   SUM()        -- add up numeric values
--   AVG()        -- compute the average
--   ROUND()      -- round a decimal to N places
-- =============================================================================

USE olist_ecommerce;


-- =============================================================================
-- QUERY 1: Total number of orders in the database
-- =============================================================================
-- COUNT(*) counts every row in the orders table.
-- We count ALL orders regardless of status so this is a full volume figure.
-- =============================================================================
SELECT
    COUNT(*)              AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customer_entries
FROM orders;


-- =============================================================================
-- QUERY 2: Orders broken down by status
-- =============================================================================
-- GROUP BY groups all rows that have the same order_status together.
-- COUNT(*) then counts how many rows are in each group.
-- ORDER BY count DESC puts the most common status first.
-- =============================================================================
SELECT
    order_status,
    COUNT(*)                              AS order_count,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM orders), 1) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- =============================================================================
-- QUERY 3: Total number of unique customers (real buyers)
-- =============================================================================
-- customer_unique_id is the true unique buyer identity.
-- A single buyer can appear multiple times in the customers table under
-- different customer_id values (one per order), so we use DISTINCT.
-- =============================================================================
SELECT
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- =============================================================================
-- QUERY 4: Total number of products and sellers
-- =============================================================================
SELECT COUNT(*) AS total_products FROM products;
SELECT COUNT(*) AS total_sellers  FROM sellers;


-- =============================================================================
-- QUERY 5: Total revenue from delivered orders
-- =============================================================================
-- We only count DELIVERED orders -- canceled and unavailable orders
-- were never received by the customer so they should not count as revenue.
-- payments.payment_value is the actual amount collected (may include vouchers).
-- We JOIN orders to payments on order_id, then SUM the payment values.
-- =============================================================================
SELECT
    COUNT(DISTINCT o.order_id)         AS delivered_orders,
    ROUND(SUM(p.payment_value), 2)     AS total_revenue_brl,
    ROUND(AVG(p.payment_value), 2)     AS avg_payment_per_row,
    ROUND(
        SUM(p.payment_value) /
        COUNT(DISTINCT o.order_id), 2) AS avg_order_revenue_brl
FROM orders  o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered';


-- =============================================================================
-- QUERY 6: Average order value (total payment per order, delivered only)
-- =============================================================================
-- Because one order can have multiple payment rows (e.g. credit card + voucher),
-- we first SUM payments per order in a subquery, then average across orders.
-- A subquery is a SELECT inside another SELECT.
-- =============================================================================
SELECT
    ROUND(AVG(order_total), 2)    AS avg_order_value_brl,
    ROUND(MIN(order_total), 2)    AS min_order_value_brl,
    ROUND(MAX(order_total), 2)    AS max_order_value_brl,
    ROUND(
        -- Median approximation: AVG of middle 50% of values
        AVG(CASE WHEN pct BETWEEN 0.25 AND 0.75 THEN order_total END)
    , 2)                          AS approx_median_order_value_brl
FROM (
    -- Subquery: total payment collected per delivered order
    SELECT
        o.order_id,
        SUM(p.payment_value)  AS order_total,
        PERCENT_RANK() OVER (ORDER BY SUM(p.payment_value)) AS pct
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
) AS order_totals;


-- =============================================================================
-- QUERY 7: Top 10 best-selling products by revenue
-- =============================================================================
-- We join order_items (which has price) with products (which has category name).
-- We only include items from delivered orders using a JOIN to orders.
-- =============================================================================
SELECT
    oi.product_id,
    COALESCE(pr.product_category_name_english,
             pr.product_category_name,
             'unknown')                      AS category,
    COUNT(*)                                  AS times_ordered,
    ROUND(SUM(oi.price), 2)                  AS total_revenue_brl,
    ROUND(AVG(oi.price), 2)                  AS avg_price_brl
FROM order_items oi
JOIN orders      o  ON oi.order_id   = o.order_id
JOIN products    pr ON oi.product_id = pr.product_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id, category
ORDER BY total_revenue_brl DESC
LIMIT 10;


-- =============================================================================
-- QUERY 8: Top 15 product categories by total revenue
-- =============================================================================
-- COALESCE returns the first non-NULL value from its list of arguments.
-- Here: use English name if available, else Portuguese, else 'unknown'.
-- =============================================================================
SELECT
    COALESCE(pr.product_category_name_english,
             pr.product_category_name,
             'unknown')            AS category,
    COUNT(DISTINCT oi.order_id)    AS orders_containing_category,
    SUM(oi.price)                  AS total_revenue_brl,
    ROUND(AVG(oi.price), 2)        AS avg_item_price_brl,
    COUNT(*)                       AS total_units_sold
FROM order_items oi
JOIN orders   o  ON oi.order_id   = o.order_id
JOIN products pr ON oi.product_id = pr.product_id
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY total_revenue_brl DESC
LIMIT 15;


-- =============================================================================
-- QUERY 9: Top 15 product categories by number of orders
-- =============================================================================
SELECT
    COALESCE(pr.product_category_name_english,
             pr.product_category_name,
             'unknown')          AS category,
    COUNT(DISTINCT oi.order_id)  AS order_count
FROM order_items oi
JOIN orders   o  ON oi.order_id   = o.order_id
JOIN products pr ON oi.product_id = pr.product_id
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY order_count DESC
LIMIT 15;


-- =============================================================================
-- QUERY 10: Orders and revenue by payment type
-- =============================================================================
-- Each payment row has a payment_type. We group by it to see which method
-- is most popular and how much revenue comes from each.
-- =============================================================================
SELECT
    payment_type,
    COUNT(DISTINCT order_id)          AS order_count,
    ROUND(SUM(payment_value), 2)      AS total_paid_brl,
    ROUND(AVG(payment_value), 2)      AS avg_payment_brl,
    ROUND(COUNT(DISTINCT order_id) * 100.0 /
          (SELECT COUNT(DISTINCT order_id) FROM payments), 1) AS pct_of_orders
FROM payments
WHERE payment_type != 'not_defined'
GROUP BY payment_type
ORDER BY order_count DESC;


-- =============================================================================
-- QUERY 11: Credit card installment usage
-- =============================================================================
-- Brazilians commonly split purchases into monthly installments (parcelamento).
-- This query shows how many customers chose each installment count.
-- =============================================================================
SELECT
    payment_installments,
    COUNT(*)                   AS payment_count,
    ROUND(SUM(payment_value), 2) AS total_paid_brl,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM payments
           WHERE payment_type = 'credit_card'), 1) AS pct_of_cc_payments
FROM payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;


-- =============================================================================
-- QUERY 12: Review score distribution
-- =============================================================================
-- review_score ranges from 1 (worst) to 5 (best).
-- ROUND(..., 1) gives one decimal place for the percentage.
-- =============================================================================
SELECT
    review_score,
    COUNT(*)                     AS review_count,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM reviews), 1) AS pct_of_reviews
FROM reviews
GROUP BY review_score
ORDER BY review_score;


-- =============================================================================
-- QUERY 13: Average review score by product category
-- =============================================================================
-- Joins four tables to connect review -> order -> order_items -> products.
-- AVG(review_score) gives the mean customer rating per category.
-- HAVING filters groups AFTER aggregation (like WHERE but for grouped results).
-- Only show categories with at least 50 reviews to avoid noisy small samples.
-- =============================================================================
SELECT
    COALESCE(pr.product_category_name_english,
             pr.product_category_name,
             'unknown')                AS category,
    COUNT(r.review_id)                 AS review_count,
    ROUND(AVG(r.review_score), 2)      AS avg_review_score,
    SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS five_star_count,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_count
FROM reviews     r
JOIN orders      o  ON r.order_id    = o.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products    pr ON oi.product_id = pr.product_id
WHERE o.order_status = 'delivered'
GROUP BY category
HAVING review_count >= 50
ORDER BY avg_review_score DESC
LIMIT 20;


-- =============================================================================
-- QUERY 14: Orders by customer state (top 15)
-- =============================================================================
-- JOIN customers to orders so we can access customer_state.
-- =============================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)         AS order_count,
    ROUND(SUM(p.payment_value), 2)     AS revenue_brl,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 /
          (SELECT COUNT(*) FROM orders
           WHERE order_status = 'delivered'), 1) AS pct_of_orders
FROM orders    o
JOIN customers c ON o.customer_id  = c.customer_id
JOIN payments  p ON o.order_id     = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY order_count DESC
LIMIT 15;


-- =============================================================================
-- QUERY 15: Monthly sales (delivered orders only)
-- =============================================================================
-- year_month is the engineered 'YYYY-MM' column we added in Phase 3.
-- This makes monthly grouping a simple GROUP BY instead of date arithmetic.
-- =============================================================================
SELECT
    year_month,
    COUNT(DISTINCT o.order_id)       AS orders,
    ROUND(SUM(p.payment_value), 2)   AS revenue_brl,
    ROUND(AVG(p.payment_value), 2)   AS avg_payment_brl
FROM orders   o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND year_month IS NOT NULL
GROUP BY year_month
ORDER BY year_month;


-- =============================================================================
-- QUERY 16: Delivery performance summary
-- =============================================================================
-- delivery_duration_days and is_late are engineered columns from Phase 3.
-- CASE WHEN ... END is MySQL's IF/ELSE inside a query.
-- =============================================================================
SELECT
    COUNT(*)                                      AS delivered_orders,
    ROUND(AVG(delivery_duration_days), 1)         AS avg_delivery_days,
    ROUND(MIN(delivery_duration_days), 1)         AS min_delivery_days,
    ROUND(MAX(delivery_duration_days), 1)         AS max_delivery_days,
    -- Percentage of orders that arrived LATE (after the estimated date)
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)
                                                  AS late_pct,
    -- Percentage that arrived EARLY
    ROUND(SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)
                                                  AS on_time_or_early_pct
FROM orders
WHERE order_status = 'delivered'
  AND delivery_duration_days IS NOT NULL;


-- =============================================================================
-- QUERY 17: Top 10 sellers by revenue
-- =============================================================================
SELECT
    oi.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id)   AS orders_fulfilled,
    ROUND(SUM(oi.price), 2)       AS total_revenue_brl,
    ROUND(AVG(oi.price), 2)       AS avg_item_price_brl
FROM order_items oi
JOIN orders  o ON oi.order_id  = o.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id, s.seller_state, s.seller_city
ORDER BY total_revenue_brl DESC
LIMIT 10;


-- =============================================================================
-- QUERY 18: Orders with multiple items vs single-item orders
-- =============================================================================
-- COUNT(*) per order_id in order_items tells us how many items each order has.
-- We then wrap that in another GROUP BY to bucket orders by item count.
-- =============================================================================
SELECT
    item_count,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(DISTINCT order_id) FROM order_items), 1) AS pct_of_orders
FROM (
    SELECT order_id, COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
) AS items_per_order
GROUP BY item_count
ORDER BY item_count;


-- =============================================================================
-- QUERY 19: Revenue by year (year-over-year comparison)
-- =============================================================================
-- purchase_year is the engineered column from Phase 3.
-- Note: 2016 has only 4 months of data and 2018 only 10 months -- incomplete years.
-- =============================================================================
SELECT
    o.purchase_year,
    COUNT(DISTINCT o.order_id)       AS order_count,
    ROUND(SUM(p.payment_value), 2)   AS revenue_brl
FROM orders   o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status   = 'delivered'
  AND o.purchase_year  IS NOT NULL
GROUP BY o.purchase_year
ORDER BY o.purchase_year;


-- =============================================================================
-- QUERY 20: Full order summary -- one row per order with all key metrics
-- =============================================================================
-- This is the kind of query a dashboard or report would use as its main data
-- source. It JOINs all seven tables together into one enriched result set.
-- =============================================================================
SELECT
    o.order_id,
    o.order_status,
    o.year_month,
    c.customer_state,
    -- Payment
    ROUND(SUM(p.payment_value), 2)      AS total_paid_brl,
    MAX(p.payment_type)                 AS primary_payment_type,
    MAX(p.payment_installments)         AS max_installments,
    -- Items
    COUNT(DISTINCT oi.order_item_id)    AS item_count,
    ROUND(SUM(oi.price), 2)             AS items_subtotal_brl,
    ROUND(SUM(oi.freight_value), 2)     AS freight_total_brl,
    -- Delivery
    o.delivery_duration_days,
    o.delivery_delay_days,
    o.is_late,
    -- Review
    r.review_score
FROM orders      o
JOIN customers   c  ON o.order_id    = c.customer_id
JOIN payments    p  ON o.order_id    = p.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
LEFT JOIN reviews r ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    o.order_id, o.order_status, o.year_month,
    c.customer_state,
    o.delivery_duration_days, o.delivery_delay_days, o.is_late,
    r.review_score
ORDER BY o.order_id
LIMIT 100;
-- Remove LIMIT to get all rows (large result set -- use with caution).
