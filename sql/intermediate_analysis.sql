-- =============================================================================
-- intermediate_analysis.sql
-- =============================================================================
-- Project : E-Commerce Sales & Customer Analytics with AI
-- Phase   : 6 -- SQL Business Analysis (Intermediate)
-- Database: olist_ecommerce
--
-- PURPOSE
-- -------
-- Intermediate-level SQL queries that JOIN multiple tables to answer
-- deeper business questions about customers, products, sellers, payments,
-- reviews, and delivery performance.
--
-- JOIN TYPES USED
-- ---------------
--   INNER JOIN  -- Returns rows that have a matching value in BOTH tables.
--                  Use when you only want records that exist on both sides.
--                  Example: only orders that have at least one payment row.
--
--   LEFT JOIN   -- Returns ALL rows from the LEFT table, plus matched rows
--                  from the right table. If no match exists on the right,
--                  the right-side columns are NULL.
--                  Use when the right-side data is optional.
--                  Example: orders that may or may not have a review.
--
-- HOW TO RUN
-- ----------
--   mysql -u root -p olist_ecommerce < sql/intermediate_analysis.sql
-- Or paste individual queries into MySQL Workbench / DBeaver.
-- =============================================================================

USE olist_ecommerce;


-- #############################################################################
-- SECTION A: CUSTOMERS AND ORDERS
-- #############################################################################

-- =============================================================================
-- A1: How many orders has each unique customer placed?
-- =============================================================================
-- We JOIN customers to orders on customer_id.
-- Then GROUP BY customer_unique_id (the real buyer identity) to aggregate
-- across all orders from the same person.
-- customer_id is order-scoped, so the same buyer can have many customer_id
-- values -- customer_unique_id is what ties them together.
-- =============================================================================
SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id)           AS total_orders,
    ROUND(
        MIN(o.order_purchase_timestamp)  -- first purchase date
    , 0)                                 AS first_purchase,
    ROUND(
        MAX(o.order_purchase_timestamp)  -- most recent purchase date
    , 0)                                 AS last_purchase
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id, c.customer_state
ORDER BY total_orders DESC
LIMIT 20;


-- =============================================================================
-- A2: One-time vs repeat customers
-- =============================================================================
-- We count orders per unique customer, then classify as repeat (> 1) or new.
-- The outer query groups by that classification.
-- =============================================================================
SELECT
    CASE
        WHEN order_count = 1 THEN 'one-time buyer'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5 orders'
        ELSE '6+ orders'
    END                               AS customer_segment,
    COUNT(*)                          AS customer_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 1)   AS pct_of_customers
FROM (
    -- Inner query: count delivered orders per unique customer
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS customer_order_counts
GROUP BY customer_segment
ORDER BY customer_count DESC;


-- =============================================================================
-- A3: Which states have the most customers and orders?
-- =============================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)  AS unique_customers,
    COUNT(DISTINCT o.order_id)            AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 1.0 /
          COUNT(DISTINCT c.customer_unique_id), 2) AS avg_orders_per_customer
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_orders DESC
LIMIT 15;


-- #############################################################################
-- SECTION B: ORDERS AND ORDER ITEMS
-- #############################################################################

-- =============================================================================
-- B1: What is the item count and subtotal for each order?
-- =============================================================================
-- We INNER JOIN orders to order_items to see the items inside each order.
-- Aggregating with SUM and COUNT gives the order-level financial picture.
-- =============================================================================
SELECT
    o.order_id,
    o.order_status,
    o.year_month,
    COUNT(oi.order_item_id)           AS item_count,
    ROUND(SUM(oi.price), 2)           AS items_total_brl,
    ROUND(SUM(oi.freight_value), 2)   AS freight_total_brl,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS grand_total_brl
FROM orders      o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.order_id, o.order_status, o.year_month
ORDER BY grand_total_brl DESC
LIMIT 20;


-- =============================================================================
-- B2: What is the distribution of item counts per order?
-- =============================================================================
-- First, count items per order (inner query).
-- Then, group by that count to see how many orders had 1 item, 2 items, etc.
-- =============================================================================
SELECT
    item_count,
    COUNT(*)                           AS orders_with_this_many_items,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 1)    AS pct_of_orders
FROM (
    SELECT
        o.order_id,
        COUNT(oi.order_item_id) AS item_count
    FROM orders      o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
) AS per_order
GROUP BY item_count
ORDER BY item_count;


-- =============================================================================
-- B3: Orders that have a payment record vs those that do not (LEFT JOIN demo)
-- =============================================================================
-- LEFT JOIN keeps all orders even if no matching payment row exists.
-- If payment_value IS NULL after the join, the order has no payment record.
-- This is a data quality check more than a business query -- good practice.
-- =============================================================================
SELECT
    CASE
        WHEN p.order_id IS NULL THEN 'No payment record'
        ELSE 'Has payment record'
    END                  AS payment_status,
    COUNT(*)             AS order_count
FROM orders o
LEFT JOIN payments p ON o.order_id = p.order_id
GROUP BY payment_status;


-- #############################################################################
-- SECTION C: PRODUCTS AND ORDER ITEMS
-- #############################################################################

-- =============================================================================
-- C1: Full product sales summary (products with AND without sales)
-- =============================================================================
-- We use LEFT JOIN from products to order_items.
-- A LEFT JOIN here means: "show all products, even ones with no orders".
-- Products with no sales will have NULL in the sales columns.
-- =============================================================================
SELECT
    pr.product_id,
    COALESCE(pr.product_category_name_english,
             pr.product_category_name, 'unknown') AS category,
    pr.is_incomplete,
    COUNT(oi.order_item_id)                        AS times_ordered,
    ROUND(SUM(oi.price), 2)                        AS total_revenue_brl,
    ROUND(AVG(oi.price), 2)                        AS avg_selling_price_brl,
    ROUND(AVG(oi.freight_value), 2)                AS avg_freight_brl
FROM products    pr
LEFT JOIN order_items oi ON pr.product_id = oi.product_id
GROUP BY pr.product_id, category, pr.is_incomplete
ORDER BY total_revenue_brl DESC
LIMIT 20;


-- =============================================================================
-- C2: Category performance: revenue, units, avg price, avg rating
-- =============================================================================
-- Four-table join: products -> order_items -> orders -> reviews
-- LEFT JOIN reviews because not every order has a review.
-- =============================================================================
SELECT
    COALESCE(pr.product_category_name_english,
             pr.product_category_name, 'unknown')  AS category,
    COUNT(DISTINCT oi.order_id)                     AS orders,
    SUM(oi.price)                                   AS revenue_brl,
    COUNT(oi.order_item_id)                         AS units_sold,
    ROUND(AVG(oi.price), 2)                         AS avg_unit_price_brl,
    ROUND(AVG(r.review_score), 2)                   AS avg_review_score
FROM products    pr
INNER JOIN order_items oi ON pr.product_id  = oi.product_id
INNER JOIN orders       o  ON oi.order_id   = o.order_id
LEFT  JOIN reviews      r  ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue_brl DESC
LIMIT 20;


-- =============================================================================
-- C3: Which categories have the highest freight cost relative to price?
-- =============================================================================
-- The freight_ratio shows what fraction of the item's price is just shipping.
-- High ratio = customer pays a lot in shipping relative to what they bought.
-- HAVING filters groups after aggregation (only categories with 100+ sales).
-- =============================================================================
SELECT
    COALESCE(pr.product_category_name_english,
             pr.product_category_name, 'unknown')    AS category,
    COUNT(oi.order_item_id)                           AS units_sold,
    ROUND(AVG(oi.price), 2)                           AS avg_price_brl,
    ROUND(AVG(oi.freight_value), 2)                   AS avg_freight_brl,
    ROUND(AVG(oi.freight_value) /
          NULLIF(AVG(oi.price), 0) * 100, 1)          AS freight_pct_of_price
FROM products    pr
INNER JOIN order_items oi ON pr.product_id = oi.product_id
INNER JOIN orders       o  ON oi.order_id  = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY category
HAVING units_sold >= 100
ORDER BY freight_pct_of_price DESC
LIMIT 15;


-- #############################################################################
-- SECTION D: PAYMENTS AND ORDERS
-- #############################################################################

-- =============================================================================
-- D1: Total payment collected per order vs total item cost
-- =============================================================================
-- This detects voucher-discounted orders (payment < item cost) or data gaps.
-- We JOIN payments and order_items both to orders, then compare the totals.
-- =============================================================================
SELECT
    o.order_id,
    o.year_month,
    ROUND(SUM(DISTINCT p.payment_value), 2)     AS total_paid_brl,
    ROUND(SUM(oi.price + oi.freight_value), 2)  AS items_plus_freight_brl,
    ROUND(
        SUM(DISTINCT p.payment_value) -
        SUM(oi.price + oi.freight_value), 2)    AS difference_brl
FROM orders      o
INNER JOIN payments    p  ON o.order_id = p.order_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.order_id, o.year_month
HAVING ABS(difference_brl) > 10     -- only show notable differences
ORDER BY difference_brl
LIMIT 20;


-- =============================================================================
-- D2: Average installments and payment value by state
-- =============================================================================
-- Joins customers (state) -> orders -> payments.
-- Shows whether certain regions pay in more installments.
-- =============================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)              AS orders,
    ROUND(AVG(p.payment_installments), 1)   AS avg_installments,
    ROUND(AVG(p.payment_value), 2)          AS avg_payment_brl,
    ROUND(SUM(p.payment_value), 2)          AS total_revenue_brl
FROM customers c
INNER JOIN orders   o ON c.customer_id = o.customer_id
INNER JOIN payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
  AND p.payment_type = 'credit_card'
GROUP BY c.customer_state
ORDER BY avg_installments DESC
LIMIT 15;


-- =============================================================================
-- D3: Orders paid with multiple payment methods (credit card + voucher combo)
-- =============================================================================
-- We group by order_id and count distinct payment_type values.
-- Orders with more than one type used a payment combination.
-- =============================================================================
SELECT
    o.order_id,
    o.year_month,
    COUNT(DISTINCT p.payment_type)      AS payment_methods_used,
    GROUP_CONCAT(DISTINCT p.payment_type
                 ORDER BY p.payment_sequential
                 SEPARATOR ' + ')       AS method_combination,
    ROUND(SUM(p.payment_value), 2)      AS total_paid_brl
FROM orders   o
INNER JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.order_id, o.year_month
HAVING payment_methods_used > 1
ORDER BY total_paid_brl DESC
LIMIT 20;


-- #############################################################################
-- SECTION E: REVIEWS AND ORDERS
-- #############################################################################

-- =============================================================================
-- E1: Orders that have a review vs those that do not (LEFT JOIN demo)
-- =============================================================================
-- LEFT JOIN keeps every order. If no matching review exists, review columns
-- are NULL. We use IS NULL / IS NOT NULL to count each group.
-- =============================================================================
SELECT
    CASE
        WHEN r.review_id IS NULL THEN 'No review'
        ELSE 'Has review'
    END               AS review_status,
    COUNT(*)          AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders o
LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY review_status;


-- =============================================================================
-- E2: Does delivery delay affect review score?
-- =============================================================================
-- We bucket orders by delay category, then average the review score.
-- CASE WHEN is MySQL's if/else inside a SELECT.
-- =============================================================================
SELECT
    CASE
        WHEN o.delivery_delay_days < -14  THEN '> 14 days early'
        WHEN o.delivery_delay_days < -7   THEN '8-14 days early'
        WHEN o.delivery_delay_days < 0    THEN '1-7 days early'
        WHEN o.delivery_delay_days = 0    THEN 'exactly on time'
        WHEN o.delivery_delay_days <= 7   THEN '1-7 days late'
        WHEN o.delivery_delay_days <= 14  THEN '8-14 days late'
        ELSE '> 14 days late'
    END                               AS delay_bucket,
    COUNT(*)                          AS order_count,
    ROUND(AVG(r.review_score), 2)     AS avg_review_score,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)      AS pct_negative_reviews
FROM orders  o
INNER JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status         = 'delivered'
  AND o.delivery_delay_days  IS NOT NULL
  AND r.review_score         IS NOT NULL
GROUP BY delay_bucket
ORDER BY MIN(o.delivery_delay_days);


-- =============================================================================
-- E3: Low-rated orders (1-2 stars) -- what can we learn about them?
-- =============================================================================
-- Joins reviews -> orders -> payments -> order_items to profile bad experiences.
-- LEFT JOIN on payments/items because some canceled orders may have limited data.
-- =============================================================================
SELECT
    r.review_score,
    COUNT(DISTINCT o.order_id)               AS order_count,
    ROUND(AVG(o.delivery_duration_days), 1)  AS avg_delivery_days,
    ROUND(AVG(o.delivery_delay_days), 1)     AS avg_delay_days,
    ROUND(AVG(p.payment_value), 2)           AS avg_order_value_brl,
    ROUND(SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
          * 100.0 / COUNT(DISTINCT o.order_id), 1) AS late_pct
FROM reviews     r
INNER JOIN orders       o  ON r.order_id   = o.order_id
LEFT  JOIN payments     p  ON o.order_id   = p.order_id
WHERE o.order_status = 'delivered'
  AND r.review_score IN (1, 2)
GROUP BY r.review_score
ORDER BY r.review_score;


-- #############################################################################
-- SECTION F: CUSTOMER SPENDING
-- #############################################################################

-- =============================================================================
-- F1: Customer lifetime value (CLV) -- total spend per unique customer
-- =============================================================================
-- Joins customers -> orders -> payments.
-- Groups by customer_unique_id so multiple orders from the same buyer are merged.
-- =============================================================================
SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id)           AS total_orders,
    ROUND(SUM(p.payment_value), 2)       AS lifetime_value_brl,
    ROUND(AVG(p.payment_value), 2)       AS avg_payment_per_row_brl,
    ROUND(SUM(p.payment_value) /
          COUNT(DISTINCT o.order_id), 2) AS avg_order_spend_brl,
    MIN(o.year_month)                    AS first_order_month,
    MAX(o.year_month)                    AS last_order_month
FROM customers c
INNER JOIN orders   o ON c.customer_id = o.customer_id
INNER JOIN payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id, c.customer_state
ORDER BY lifetime_value_brl DESC
LIMIT 20;


-- =============================================================================
-- F2: Average spending per customer by state
-- =============================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)       AS unique_customers,
    ROUND(SUM(p.payment_value), 2)             AS total_revenue_brl,
    ROUND(SUM(p.payment_value) /
          COUNT(DISTINCT c.customer_unique_id), 2) AS avg_clv_brl,
    ROUND(AVG(p.payment_value), 2)             AS avg_payment_brl
FROM customers c
INNER JOIN orders   o ON c.customer_id = o.customer_id
INNER JOIN payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY avg_clv_brl DESC;


-- =============================================================================
-- F3: Top spending customers with review behaviour
-- =============================================================================
-- Joins customers, orders, payments, and reviews.
-- LEFT JOIN reviews -- some customers may not have left any reviews.
-- =============================================================================
SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id)            AS orders,
    ROUND(SUM(p.payment_value), 2)        AS total_spent_brl,
    ROUND(AVG(r.review_score), 2)         AS avg_review_score,
    COUNT(r.review_id)                    AS reviews_written
FROM customers c
INNER JOIN orders   o  ON c.customer_id = o.customer_id
INNER JOIN payments p  ON o.order_id    = p.order_id
LEFT  JOIN reviews  r  ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id, c.customer_state
ORDER BY total_spent_brl DESC
LIMIT 20;


-- #############################################################################
-- SECTION G: SELLER PERFORMANCE
-- #############################################################################

-- =============================================================================
-- G1: Seller performance scorecard
-- =============================================================================
-- Joins sellers -> order_items -> orders -> reviews.
-- LEFT JOIN reviews -- not every order has a review.
-- Gives a complete picture of each seller: revenue, volume, rating, late rate.
-- =============================================================================
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)              AS orders_fulfilled,
    COUNT(oi.order_item_id)                  AS units_sold,
    ROUND(SUM(oi.price), 2)                  AS total_revenue_brl,
    ROUND(AVG(oi.price), 2)                  AS avg_item_price_brl,
    ROUND(AVG(r.review_score), 2)            AS avg_review_score,
    ROUND(
        SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT oi.order_id), 1) AS late_delivery_pct
FROM sellers     s
INNER JOIN order_items oi ON s.seller_id   = oi.seller_id
INNER JOIN orders       o  ON oi.order_id  = o.order_id
LEFT  JOIN reviews      r  ON o.order_id   = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state
ORDER BY total_revenue_brl DESC
LIMIT 20;


-- =============================================================================
-- G2: Seller performance by state (aggregate)
-- =============================================================================
SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id)              AS seller_count,
    COUNT(DISTINCT oi.order_id)              AS orders_fulfilled,
    ROUND(SUM(oi.price), 2)                  AS total_revenue_brl,
    ROUND(AVG(r.review_score), 2)            AS avg_review_score,
    ROUND(
        SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT oi.order_id), 1) AS late_pct
FROM sellers     s
INNER JOIN order_items oi ON s.seller_id   = oi.seller_id
INNER JOIN orders       o  ON oi.order_id  = o.order_id
LEFT  JOIN reviews      r  ON o.order_id   = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY total_revenue_brl DESC;


-- =============================================================================
-- G3: Sellers who sell products in multiple categories
-- =============================================================================
SELECT
    oi.seller_id,
    s.seller_state,
    COUNT(DISTINCT pr.product_category_name_english)  AS categories_sold,
    GROUP_CONCAT(DISTINCT pr.product_category_name_english
                 ORDER BY pr.product_category_name_english
                 SEPARATOR ', ')                       AS category_list,
    COUNT(DISTINCT oi.order_id)                       AS total_orders
FROM order_items oi
INNER JOIN sellers  s  ON oi.seller_id  = s.seller_id
INNER JOIN products pr ON oi.product_id = pr.product_id
INNER JOIN orders   o  ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
  AND pr.product_category_name_english IS NOT NULL
GROUP BY oi.seller_id, s.seller_state
HAVING categories_sold > 1
ORDER BY categories_sold DESC
LIMIT 20;


-- #############################################################################
-- SECTION H: DELIVERY PERFORMANCE
-- #############################################################################

-- =============================================================================
-- H1: Delivery performance by customer state
-- =============================================================================
-- Joins customers (state) -> orders (delivery metrics).
-- INNER JOIN because we only care about orders that have a matched customer.
-- =============================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)                AS delivered_orders,
    ROUND(AVG(o.delivery_duration_days), 1)   AS avg_delivery_days,
    ROUND(MIN(o.delivery_duration_days), 1)   AS fastest_days,
    ROUND(MAX(o.delivery_duration_days), 1)   AS slowest_days,
    ROUND(
        SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT o.order_id), 1) AS late_pct
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status              = 'delivered'
  AND o.delivery_duration_days    IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_pct DESC;


-- =============================================================================
-- H2: Delivery speed by seller state (does seller location affect speed?)
-- =============================================================================
SELECT
    s.seller_state,
    COUNT(DISTINCT o.order_id)                AS orders,
    ROUND(AVG(o.delivery_duration_days), 1)   AS avg_delivery_days,
    ROUND(AVG(o.carrier_handling_days), 1)    AS avg_handling_days,
    ROUND(
        SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT o.order_id), 1) AS late_pct
FROM sellers     s
INNER JOIN order_items oi ON s.seller_id  = oi.seller_id
INNER JOIN orders       o  ON oi.order_id = o.order_id
WHERE o.order_status           = 'delivered'
  AND o.delivery_duration_days IS NOT NULL
GROUP BY s.seller_state
HAVING orders >= 100
ORDER BY avg_delivery_days;


-- =============================================================================
-- H3: Monthly late delivery trend
-- =============================================================================
-- Shows whether on-time performance improved or worsened month over month.
-- =============================================================================
SELECT
    o.year_month,
    COUNT(*)                                   AS delivered_orders,
    ROUND(AVG(o.delivery_duration_days), 1)    AS avg_delivery_days,
    ROUND(
        SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1)                 AS late_pct,
    ROUND(AVG(r.review_score), 2)              AS avg_review_score
FROM orders  o
LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status           = 'delivered'
  AND o.year_month             IS NOT NULL
  AND o.delivery_duration_days IS NOT NULL
GROUP BY o.year_month
ORDER BY o.year_month;


-- =============================================================================
-- H4: Full delivery + review scorecard per order (sample)
-- =============================================================================
-- Seven-column result combining every delivery and satisfaction metric.
-- LEFT JOIN reviews -- some orders have no review.
-- LEFT JOIN payments -- rare edge case: a delivered order with no payment row.
-- =============================================================================
SELECT
    o.order_id,
    c.customer_state,
    s.seller_state,
    o.year_month,
    o.delivery_duration_days,
    o.delivery_delay_days,
    o.is_late,
    o.carrier_handling_days,
    r.review_score,
    ROUND(SUM(p.payment_value), 2) AS total_paid_brl
FROM orders      o
INNER JOIN customers   c  ON o.customer_id  = c.customer_id
INNER JOIN order_items oi ON o.order_id     = oi.order_id
INNER JOIN sellers     s  ON oi.seller_id   = s.seller_id
LEFT  JOIN reviews     r  ON o.order_id     = r.order_id
LEFT  JOIN payments    p  ON o.order_id     = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    o.order_id, c.customer_state, s.seller_state, o.year_month,
    o.delivery_duration_days, o.delivery_delay_days,
    o.is_late, o.carrier_handling_days, r.review_score
ORDER BY o.delivery_delay_days DESC
LIMIT 50;
