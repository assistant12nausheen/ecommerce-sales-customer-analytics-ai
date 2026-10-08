-- =============================================================================
-- advanced_analysis.sql
-- =============================================================================
-- Project : E-Commerce Sales & Customer Analytics with AI
-- Phase   : 6 -- SQL Business Analysis (Advanced)
-- Database: olist_ecommerce
--
-- PURPOSE
-- -------
-- Advanced SQL queries using CTEs, subqueries, CASE statements, and
-- window functions. Each query is explained step by step so a B.Tech
-- Data Analytics student can understand both the syntax and the business
-- reason behind it.
--
-- SQL CONCEPTS COVERED
-- --------------------
--   CTE (WITH clause)     -- a named temporary result you can reference in the
--                            same query; makes complex queries more readable
--   Subquery              -- a SELECT nested inside another SELECT, FROM, or WHERE
--   CASE WHEN             -- conditional logic (if/else) inside SQL
--   Window functions      -- calculations across a set of rows related to the
--                            current row WITHOUT collapsing them into groups
--     RANK()              -- 1,2,2,4 (ties share a rank; next rank is skipped)
--     DENSE_RANK()        -- 1,2,2,3 (ties share a rank; no rank is skipped)
--     ROW_NUMBER()        -- 1,2,3,4 (unique sequential number, no ties)
--     LAG(col, n)         -- value of col from n rows BEFORE the current row
--     LEAD(col, n)        -- value of col from n rows AFTER  the current row
--     SUM() OVER (...)    -- running total
--     AVG() OVER (...)    -- rolling/moving average
--     PERCENT_RANK()      -- relative position (0.0 to 1.0) within a partition
--
-- HOW TO RUN
-- ----------
--   mysql -u root -p olist_ecommerce < sql/advanced_analysis.sql
-- Or paste individual query blocks into MySQL Workbench / DBeaver.
-- =============================================================================

USE olist_ecommerce;


-- #############################################################################
-- SECTION 1: CTEs (Common Table Expressions)
-- #############################################################################

-- =============================================================================
-- Q1: Month-over-month revenue growth using a CTE + LAG
-- =============================================================================
-- WHAT IT DOES:
--   Calculates monthly revenue and then computes the growth percentage
--   compared with the previous month.
--
-- WHY USEFUL:
--   Identifying which months had strong growth vs slowdowns is a core
--   business KPI. Investors and managers watch this every month.
--
-- SQL CONCEPTS:
--   CTE (WITH monthly_revenue AS ...)
--   LAG(revenue, 1)  -- pulls the previous month's revenue into the current row
--   ROUND / NULLIF   -- prevents division-by-zero when previous month is NULL
-- =============================================================================
WITH monthly_revenue AS (
    -- Step 1: aggregate total revenue and order count per month
    SELECT
        o.year_month,
        COUNT(DISTINCT o.order_id)       AS order_count,
        ROUND(SUM(p.payment_value), 2)   AS revenue
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    GROUP BY o.year_month
)
-- Step 2: use LAG to compare each month with the one before it
SELECT
    year_month,
    order_count,
    revenue,
    LAG(revenue, 1) OVER (ORDER BY year_month)   AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue, 1) OVER (ORDER BY year_month))
        / NULLIF(LAG(revenue, 1) OVER (ORDER BY year_month), 0)
        * 100
    , 1)                                          AS revenue_growth_pct
FROM monthly_revenue
ORDER BY year_month;


-- =============================================================================
-- Q2: Running total of revenue over time
-- =============================================================================
-- WHAT IT DOES:
--   Shows cumulative (running) revenue from the very first month up to each
--   month, so you can see how quickly the platform reached each milestone.
--
-- WHY USEFUL:
--   A running total is used in fundraising decks, annual reports, and
--   trend dashboards to show "total sales to date".
--
-- SQL CONCEPTS:
--   CTE for monthly aggregation
--   SUM(revenue) OVER (ORDER BY year_month ROWS UNBOUNDED PRECEDING)
--     -- adds up all revenue from the first row up to the current row
-- =============================================================================
WITH monthly AS (
    SELECT
        o.year_month,
        ROUND(SUM(p.payment_value), 2) AS revenue
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    GROUP BY o.year_month
)
SELECT
    year_month,
    revenue,
    SUM(revenue) OVER (
        ORDER BY year_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                   AS running_total,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY year_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
        / SUM(revenue) OVER () * 100
    , 1)                                AS cumulative_pct_of_total
FROM monthly
ORDER BY year_month;


-- =============================================================================
-- Q3: 3-month rolling average revenue (smoothing noise)
-- =============================================================================
-- WHAT IT DOES:
--   Calculates the average revenue of the current month + the 2 months before.
--   This smooths out single-month spikes (like a flash sale or holiday).
--
-- WHY USEFUL:
--   A 3-month moving average is the simplest way to see the underlying trend
--   in a time series, removing short-term noise.
--
-- SQL CONCEPTS:
--   AVG(revenue) OVER (ORDER BY year_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
-- =============================================================================
WITH monthly AS (
    SELECT
        o.year_month,
        ROUND(SUM(p.payment_value), 2) AS revenue
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    GROUP BY o.year_month
)
SELECT
    year_month,
    revenue,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY year_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )
    , 2)                              AS rolling_3m_avg_revenue,
    LAG(revenue, 1) OVER (ORDER BY year_month) AS prev_month
FROM monthly
ORDER BY year_month;


-- #############################################################################
-- SECTION 2: RANKING FUNCTIONS
-- #############################################################################

-- =============================================================================
-- Q4: Rank product categories by revenue using RANK, DENSE_RANK, ROW_NUMBER
-- =============================================================================
-- WHAT IT DOES:
--   Ranks every product category by total revenue and demonstrates the
--   three ranking functions side by side so you can see how they differ.
--
-- WHY USEFUL:
--   Rankings let you answer "which category is #1, #2 ...?" and are widely
--   used in leaderboards, top-N reports, and inventory prioritisation.
--
-- SQL CONCEPTS:
--   RANK()        -- if two categories tie for 2nd, both get 2, next is 4
--   DENSE_RANK()  -- if two categories tie for 2nd, both get 2, next is 3
--   ROW_NUMBER()  -- assigns a unique number even if revenues are equal
-- =============================================================================
WITH category_revenue AS (
    SELECT
        COALESCE(pr.product_category_name_english,
                 pr.product_category_name, 'unknown') AS category,
        ROUND(SUM(oi.price), 2)                        AS total_revenue
    FROM order_items oi
    JOIN orders   o  ON oi.order_id   = o.order_id
    JOIN products pr ON oi.product_id = pr.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY category
)
SELECT
    category,
    total_revenue,
    RANK()       OVER (ORDER BY total_revenue DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS dense_rank,
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS row_num
FROM category_revenue
ORDER BY total_revenue DESC
LIMIT 20;


-- =============================================================================
-- Q5: Top 3 selling products WITHIN each category (RANK within partitions)
-- =============================================================================
-- WHAT IT DOES:
--   Finds the top 3 revenue-generating products inside every category.
--   The ranking resets to 1 at the start of each new category.
--
-- WHY USEFUL:
--   Managers want to know: "In Health & Beauty, which 3 products make the
--   most money?" This requires ranking WITHIN groups -- which window
--   functions handle perfectly.
--
-- SQL CONCEPTS:
--   RANK() OVER (PARTITION BY category ORDER BY revenue DESC)
--   PARTITION BY  -- restarts the ranking for each category
--   Outer WHERE filters to only keep rank <= 3
-- =============================================================================
WITH product_revenue AS (
    SELECT
        COALESCE(pr.product_category_name_english,
                 pr.product_category_name, 'unknown') AS category,
        oi.product_id,
        ROUND(SUM(oi.price), 2)   AS revenue,
        COUNT(oi.order_item_id)   AS units_sold
    FROM order_items oi
    JOIN orders   o  ON oi.order_id   = o.order_id
    JOIN products pr ON oi.product_id = pr.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY category, oi.product_id
),
ranked AS (
    SELECT
        category,
        product_id,
        revenue,
        units_sold,
        RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
)
SELECT *
FROM ranked
WHERE rank_in_category <= 3
  AND category != 'unknown'
ORDER BY category, rank_in_category
LIMIT 60;


-- =============================================================================
-- Q6: Rank sellers by revenue and identify top-10% sellers
-- =============================================================================
-- WHAT IT DOES:
--   Ranks every seller by revenue and uses PERCENT_RANK to flag the top 10%
--   as "high performers" -- a common segmentation technique.
--
-- WHY USEFUL:
--   The Pareto principle often holds in e-commerce: roughly 20% of sellers
--   drive 80% of revenue. Identifying them helps prioritise support.
--
-- SQL CONCEPTS:
--   PERCENT_RANK() OVER (ORDER BY revenue DESC)
--     returns a value from 0.0 (highest) to 1.0 (lowest)
--   CASE WHEN to translate percentile into a label
-- =============================================================================
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        ROUND(SUM(oi.price), 2)       AS revenue,
        COUNT(DISTINCT oi.order_id)   AS orders
    FROM order_items oi
    JOIN orders  o ON oi.order_id  = o.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
)
SELECT
    seller_id,
    seller_state,
    orders,
    revenue,
    DENSE_RANK()   OVER (ORDER BY revenue DESC)     AS revenue_rank,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY revenue DESC) * 100
    , 1)                                            AS percentile_desc,
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY revenue DESC) <= 0.10
             THEN 'Top 10%'
        WHEN PERCENT_RANK() OVER (ORDER BY revenue DESC) <= 0.25
             THEN 'Top 25%'
        WHEN PERCENT_RANK() OVER (ORDER BY revenue DESC) <= 0.50
             THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END                                             AS seller_tier
FROM seller_revenue
ORDER BY revenue DESC
LIMIT 30;


-- #############################################################################
-- SECTION 3: CASE STATEMENTS FOR SEGMENTATION
-- #############################################################################

-- =============================================================================
-- Q7: RFM segmentation using CASE statements
-- =============================================================================
-- WHAT IT DOES:
--   Classifies every unique customer into a segment (Champion, Loyal,
--   At Risk, etc.) based on their Recency, Frequency, and Monetary scores.
--
-- WHY USEFUL:
--   RFM segmentation is the most widely used customer analysis technique
--   in e-commerce. It directly drives marketing decisions:
--   re-engage "At Risk" customers, reward "Champions", etc.
--
-- SQL CONCEPTS:
--   Multiple CTEs chained together
--   NTILE(4) -- splits customers into 4 equally-sized buckets by each metric
--   Nested CASE WHEN for multi-condition classification
-- =============================================================================
WITH rfm_base AS (
    -- Step 1: compute raw RFM values per customer
    SELECT
        c.customer_unique_id,
        DATEDIFF(
            (SELECT MAX(order_purchase_timestamp) FROM orders
             WHERE order_status = 'delivered'),
            MAX(o.order_purchase_timestamp)
        )                                    AS recency_days,
        COUNT(DISTINCT o.order_id)           AS frequency,
        ROUND(SUM(p.payment_value), 2)       AS monetary
    FROM customers c
    JOIN orders   o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id    = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scored AS (
    -- Step 2: score each dimension 1-4 using NTILE
    -- Recency  : lower days = more recent = better, so we ORDER DESC -> lower score
    -- Frequency: more orders = better, ORDER ASC -> NTILE gives 4 to high freq
    -- Monetary : more spend  = better, ORDER ASC -> NTILE gives 4 to high spend
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        5 - NTILE(4) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(4)     OVER (ORDER BY frequency  ASC)     AS f_score,
        NTILE(4)     OVER (ORDER BY monetary   ASC)     AS m_score
    FROM rfm_base
),
rfm_segment AS (
    -- Step 3: combine scores into a single label
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score) AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                 THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3
                 THEN 'Loyal Customer'
            WHEN r_score >= 3 AND f_score = 1
                 THEN 'Recent Customer'
            WHEN r_score = 1 AND f_score >= 3
                 THEN 'At Risk'
            WHEN r_score = 1 AND f_score = 1
                 THEN 'Lost'
            ELSE 'Potential Loyalist'
        END                           AS segment
    FROM rfm_scored
)
-- Step 4: summarise each segment
SELECT
    segment,
    COUNT(*)                          AS customer_count,
    ROUND(AVG(recency_days), 0)       AS avg_recency_days,
    ROUND(AVG(frequency), 1)          AS avg_orders,
    ROUND(AVG(monetary), 2)           AS avg_spend_brl,
    ROUND(SUM(monetary), 2)           AS total_segment_revenue
FROM rfm_segment
GROUP BY segment
ORDER BY total_segment_revenue DESC;


-- =============================================================================
-- Q8: Order value tier analysis with CASE
-- =============================================================================
-- WHAT IT DOES:
--   Buckets every delivered order into value tiers (low/medium/high/premium)
--   and shows how many orders fall into each tier and their revenue share.
--
-- WHY USEFUL:
--   Helps identify whether the business is driven by many small orders or
--   fewer large ones -- critical input for pricing and logistics strategy.
--
-- SQL CONCEPTS:
--   CASE WHEN on an aggregated value (SUM per order subquery)
--   SUM(revenue) OVER () -- total revenue for percentage calculation
-- =============================================================================
WITH order_totals AS (
    SELECT
        o.order_id,
        o.year_month,
        ROUND(SUM(p.payment_value), 2) AS order_value
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.year_month
),
tiered AS (
    SELECT
        order_id,
        year_month,
        order_value,
        CASE
            WHEN order_value <  50  THEN 'Low     (< R$50)'
            WHEN order_value <  150 THEN 'Medium  (R$50–149)'
            WHEN order_value <  500 THEN 'High    (R$150–499)'
            ELSE                         'Premium (R$500+)'
        END AS value_tier
    FROM order_totals
)
SELECT
    value_tier,
    COUNT(*)                               AS order_count,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER (), 1)      AS pct_of_orders,
    ROUND(SUM(order_value), 2)             AS total_revenue,
    ROUND(SUM(order_value) * 100.0
          / SUM(SUM(order_value)) OVER (), 1) AS pct_of_revenue,
    ROUND(AVG(order_value), 2)             AS avg_order_value
FROM tiered
GROUP BY value_tier
ORDER BY MIN(order_value);


-- #############################################################################
-- SECTION 4: ADVANCED WINDOW FUNCTIONS
-- #############################################################################

-- =============================================================================
-- Q9: First and most recent purchase per customer (ROW_NUMBER)
-- =============================================================================
-- WHAT IT DOES:
--   For every unique customer finds their very first order and their most
--   recent order by assigning row numbers within each customer's order history.
--
-- WHY USEFUL:
--   Knowing the first purchase gives the customer acquisition date.
--   Knowing the last purchase helps identify customers going inactive.
--
-- SQL CONCEPTS:
--   ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY timestamp)
--   Two separate CTEs -- one for first order, one for last order
--   Joining the two CTEs by customer_unique_id
-- =============================================================================
WITH orders_numbered AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.year_month,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp ASC
        )  AS row_asc,     -- 1 = earliest order
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp DESC
        )  AS row_desc     -- 1 = most recent order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_orders AS (
    SELECT customer_unique_id, order_id AS first_order_id,
           year_month AS first_month
    FROM orders_numbered WHERE row_asc = 1
),
last_orders AS (
    SELECT customer_unique_id, order_id AS last_order_id,
           year_month AS last_month
    FROM orders_numbered WHERE row_desc = 1
)
SELECT
    f.customer_unique_id,
    f.first_order_id,
    f.first_month,
    l.last_order_id,
    l.last_month,
    CASE
        WHEN f.first_order_id = l.last_order_id THEN 'one-time buyer'
        ELSE 'repeat buyer'
    END AS buyer_type
FROM first_orders f
JOIN last_orders  l ON f.customer_unique_id = l.customer_unique_id
ORDER BY f.first_month
LIMIT 30;


-- =============================================================================
-- Q10: Month-over-month order count change (LAG + LEAD together)
-- =============================================================================
-- WHAT IT DOES:
--   For each month shows the order count, the previous month's count (LAG),
--   and the next month's count (LEAD), plus the change in both directions.
--
-- WHY USEFUL:
--   Useful for forecasting and anomaly detection -- if this month dropped
--   vs last month AND next month is also low, it is a real trend,
--   not just a one-month blip.
--
-- SQL CONCEPTS:
--   LAG(col, 1)  -- look back 1 row (previous month)
--   LEAD(col, 1) -- look forward 1 row (next month)
-- =============================================================================
WITH monthly_orders AS (
    SELECT
        year_month,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders
    WHERE order_status = 'delivered'
      AND year_month   IS NOT NULL
    GROUP BY year_month
)
SELECT
    year_month,
    order_count,
    LAG(order_count,  1) OVER (ORDER BY year_month)  AS prev_month_orders,
    LEAD(order_count, 1) OVER (ORDER BY year_month)  AS next_month_orders,
    order_count
        - LAG(order_count, 1) OVER (ORDER BY year_month)  AS change_from_prev,
    ROUND(
        (order_count - LAG(order_count, 1) OVER (ORDER BY year_month))
        / NULLIF(LAG(order_count, 1) OVER (ORDER BY year_month), 0)
        * 100
    , 1)                                              AS growth_pct_vs_prev
FROM monthly_orders
ORDER BY year_month;


-- =============================================================================
-- Q11: Running count of new customers acquired each month
-- =============================================================================
-- WHAT IT DOES:
--   Counts how many brand-new unique customers placed their first-ever order
--   each month, and computes a running total of total customers acquired.
--
-- WHY USEFUL:
--   Customer acquisition pace is one of the most important growth metrics.
--   A running total shows when the platform reached 10k, 50k, 100k customers.
--
-- SQL CONCEPTS:
--   ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY timestamp)
--   to identify each customer's first order
--   SUM(new_customers) OVER (ORDER BY ...) for the running total
-- =============================================================================
WITH first_orders AS (
    -- Keep only each customer's very first delivered order
    SELECT
        c.customer_unique_id,
        o.year_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY o.order_purchase_timestamp
    ) = 1
),
monthly_new AS (
    SELECT
        year_month,
        COUNT(*) AS new_customers
    FROM first_orders
    GROUP BY year_month
)
SELECT
    year_month,
    new_customers,
    SUM(new_customers) OVER (
        ORDER BY year_month
        ROWS UNBOUNDED PRECEDING
    )                  AS cumulative_customers
FROM monthly_new
ORDER BY year_month;


-- =============================================================================
-- Q12: Seller revenue quartiles (NTILE)
-- =============================================================================
-- WHAT IT DOES:
--   Divides all sellers into 4 equal groups (quartiles) by revenue.
--   Q4 = top 25% earners, Q1 = bottom 25%.
--
-- WHY USEFUL:
--   Quartile analysis is a standard descriptive statistics technique.
--   It answers: "What revenue does a typical top-quartile seller generate?"
--
-- SQL CONCEPTS:
--   NTILE(4) splits rows into n roughly equal groups numbered 1..n
-- =============================================================================
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)   AS orders,
        ROUND(SUM(oi.price), 2)       AS revenue
    FROM order_items oi
    JOIN orders  o ON oi.order_id  = o.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
)
SELECT
    NTILE(4) OVER (ORDER BY revenue ASC)  AS quartile,  -- Q4 = highest revenue
    COUNT(*)                               AS seller_count,
    ROUND(MIN(revenue), 2)                 AS min_revenue,
    ROUND(AVG(revenue), 2)                 AS avg_revenue,
    ROUND(MAX(revenue), 2)                 AS max_revenue,
    ROUND(SUM(revenue), 2)                 AS total_revenue
FROM seller_revenue
GROUP BY quartile
ORDER BY quartile DESC;


-- #############################################################################
-- SECTION 5: COMPLEX MULTI-CTE ANALYSIS
-- #############################################################################

-- =============================================================================
-- Q13: Monthly cohort retention -- how many customers returned the next month?
-- =============================================================================
-- WHAT IT DOES:
--   For each month finds customers who ordered, then checks whether they also
--   ordered the following month. The retention rate shows how sticky the
--   platform is.
--
-- WHY USEFUL:
--   Retention rate is one of the most important indicators of product-market
--   fit. Even a 1% improvement in retention can significantly boost revenue.
--
-- SQL CONCEPTS:
--   SELF-JOIN on the same CTE (customers in month M joined to month M+1)
--   LEAD(year_month, 1)  -- checks if the customer's next order was the next month
-- =============================================================================
WITH customer_months AS (
    -- One row per (customer, month) combination where they placed an order
    SELECT DISTINCT
        c.customer_unique_id,
        o.year_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
),
with_next AS (
    SELECT
        customer_unique_id,
        year_month,
        LEAD(year_month, 1) OVER (
            PARTITION BY customer_unique_id
            ORDER BY year_month
        ) AS next_active_month
    FROM customer_months
)
SELECT
    year_month,
    COUNT(DISTINCT customer_unique_id)               AS active_customers,
    COUNT(DISTINCT CASE
        WHEN next_active_month = DATE_FORMAT(
                 STR_TO_DATE(CONCAT(year_month, '-01'), '%Y-%m-%d')
                 + INTERVAL 1 MONTH, '%Y-%m')
        THEN customer_unique_id END)                 AS retained_next_month,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN next_active_month = DATE_FORMAT(
                     STR_TO_DATE(CONCAT(year_month, '-01'), '%Y-%m-%d')
                     + INTERVAL 1 MONTH, '%Y-%m')
            THEN customer_unique_id END)
        * 100.0
        / NULLIF(COUNT(DISTINCT customer_unique_id), 0)
    , 1)                                             AS retention_pct
FROM with_next
GROUP BY year_month
ORDER BY year_month;


-- =============================================================================
-- Q14: Category market share and revenue concentration
-- =============================================================================
-- WHAT IT DOES:
--   Shows what percentage of total platform revenue each category contributes,
--   with a running cumulative share to identify the categories that together
--   account for 80% of revenue (Pareto / 80-20 rule).
--
-- WHY USEFUL:
--   The 80/20 rule in retail: usually 20% of categories drive 80% of revenue.
--   This query makes that visible and quantifies it precisely.
--
-- SQL CONCEPTS:
--   Two CTEs: one for category revenue, one for the total platform revenue
--   SUM(revenue) OVER (ORDER BY ...) for the running cumulative share
-- =============================================================================
WITH cat_rev AS (
    SELECT
        COALESCE(pr.product_category_name_english,
                 pr.product_category_name, 'unknown') AS category,
        ROUND(SUM(oi.price), 2)                        AS revenue
    FROM order_items oi
    JOIN orders   o  ON oi.order_id   = o.order_id
    JOIN products pr ON oi.product_id = pr.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY category
),
total AS (
    SELECT SUM(revenue) AS platform_revenue FROM cat_rev
)
SELECT
    cr.category,
    cr.revenue,
    ROUND(cr.revenue / t.platform_revenue * 100, 2)  AS revenue_share_pct,
    ROUND(
        SUM(cr.revenue) OVER (
            ORDER BY cr.revenue DESC
            ROWS UNBOUNDED PRECEDING
        ) / t.platform_revenue * 100
    , 1)                                              AS cumulative_share_pct,
    DENSE_RANK() OVER (ORDER BY cr.revenue DESC)      AS revenue_rank
FROM cat_rev cr
CROSS JOIN total t
ORDER BY cr.revenue DESC
LIMIT 30;


-- =============================================================================
-- Q15: Full monthly business dashboard in one query
-- =============================================================================
-- WHAT IT DOES:
--   A single query that produces a complete month-by-month dashboard row
--   with revenue, orders, new customers, avg review, late rate, and
--   growth vs the prior month -- all in one result set.
--
-- WHY USEFUL:
--   This is the kind of query a BI tool (Metabase, Grafana, Tableau)
--   would run to populate a management dashboard. It demonstrates how to
--   combine all the techniques learned above into one readable CTE chain.
--
-- SQL CONCEPTS:
--   Five chained CTEs, each building on the previous
--   LAG for growth calculation
--   LEFT JOIN between CTEs (some months may lack review data)
-- =============================================================================
WITH monthly_revenue AS (
    SELECT
        o.year_month,
        COUNT(DISTINCT o.order_id)        AS orders,
        ROUND(SUM(p.payment_value), 2)    AS revenue
    FROM orders   o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    GROUP BY o.year_month
),
monthly_customers AS (
    -- new unique customers per month (first-ever order)
    SELECT
        sub.year_month,
        COUNT(*) AS new_customers
    FROM (
        SELECT
            c.customer_unique_id,
            MIN(o.year_month) AS year_month
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    ) sub
    GROUP BY sub.year_month
),
monthly_reviews AS (
    SELECT
        o.year_month,
        ROUND(AVG(r.review_score), 2) AS avg_review_score
    FROM orders  o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.year_month   IS NOT NULL
    GROUP BY o.year_month
),
monthly_delivery AS (
    SELECT
        year_month,
        ROUND(
            SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*), 1
        ) AS late_pct,
        ROUND(AVG(delivery_duration_days), 1) AS avg_delivery_days
    FROM orders
    WHERE order_status = 'delivered'
      AND year_month   IS NOT NULL
    GROUP BY year_month
)
SELECT
    mr.year_month,
    mr.orders,
    mr.revenue,
    ROUND(mr.revenue - LAG(mr.revenue, 1) OVER (ORDER BY mr.year_month), 2)
                                          AS revenue_vs_prev_month,
    ROUND(
        (mr.revenue - LAG(mr.revenue, 1) OVER (ORDER BY mr.year_month))
        / NULLIF(LAG(mr.revenue, 1) OVER (ORDER BY mr.year_month), 0) * 100
    , 1)                                  AS growth_pct,
    mc.new_customers,
    rv.avg_review_score,
    dl.late_pct,
    dl.avg_delivery_days,
    SUM(mr.revenue) OVER (
        ORDER BY mr.year_month
        ROWS UNBOUNDED PRECEDING
    )                                     AS cumulative_revenue
FROM monthly_revenue   mr
LEFT JOIN monthly_customers mc ON mr.year_month = mc.year_month
LEFT JOIN monthly_reviews   rv ON mr.year_month = rv.year_month
LEFT JOIN monthly_delivery  dl ON mr.year_month = dl.year_month
ORDER BY mr.year_month;
