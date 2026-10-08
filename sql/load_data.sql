-- =============================================================================
-- load_data.sql
-- =============================================================================
-- Project : E-Commerce Sales & Customer Analytics with AI
-- Phase   : 5 -- SQL Database Creation
-- Dataset : Cleaned CSV files from data/cleaned/
--
-- PURPOSE
-- -------
-- Loads the cleaned CSV files into the olist_ecommerce database tables
-- created by sql/schema.sql.
--
-- HOW TO RUN
-- ----------
-- Step 1: Make sure MySQL is running and you have already run schema.sql.
-- Step 2: MySQL must have LOCAL file access enabled. Run once in MySQL:
--           SET GLOBAL local_infile = 1;
-- Step 3: Run this file with LOCAL infile support enabled:
--           mysql --local-infile=1 -u root -p olist_ecommerce < sql/load_data.sql
--
-- ALTERNATIVE (Python loader -- recommended for beginners)
-- ---------------------------------------------------------
-- Run  python/db_seed.py  instead of this file. The Python script uses
-- pandas + SQLAlchemy and works without any MySQL file-permission setup.
--
-- IMPORTANT NOTES
-- ---------------
-- 1. The file paths below use the ABSOLUTE path of the data/cleaned/ folder.
--    If you move the project folder, update DATA_DIR at the top.
-- 2. LOAD ORDER matters: parent tables (customers, products, sellers) must be
--    loaded BEFORE child tables (orders, order_items, payments, reviews).
-- 3. DATE/DATETIME columns are stored as strings in the CSVs ("YYYY-MM-DD HH:MM:SS").
--    MySQL parses them automatically when the column type is DATETIME.
-- 4. Boolean column is_late is stored as True/False (Python). MySQL maps
--    True -> 1, False -> 0.
-- 5. The is_incomplete boolean is stored as True/False in products_clean.csv.
--
-- UPDATE THE PATH BELOW TO MATCH YOUR MACHINE
-- --------------------------------------------
-- Replace  C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned
-- with the actual absolute path on your system (use forward slashes).
-- =============================================================================

USE olist_ecommerce;

-- Temporarily disable FK checks so we can truncate/reload tables freely.
-- We re-enable them at the end.
SET FOREIGN_KEY_CHECKS = 0;


-- ===========================================================================
-- 1. CUSTOMERS
-- ===========================================================================
-- Source file : data/cleaned/customers_clean.csv
-- Columns     : customer_id, customer_unique_id, customer_zip_code_prefix,
--               customer_city, customer_state
-- ===========================================================================
TRUNCATE TABLE customers;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/customers_clean.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES                       -- skip the header row
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);


-- ===========================================================================
-- 2. PRODUCTS
-- ===========================================================================
-- Source file : data/cleaned/products_clean.csv
-- Note        : is_incomplete is True/False (Python bool) -> MySQL stores as 1/0
-- ===========================================================================
TRUNCATE TABLE products;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/products_clean.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    is_incomplete,
    product_category_name_english
);


-- ===========================================================================
-- 3. SELLERS
-- ===========================================================================
-- Source file : data/cleaned/sellers_clean.csv
-- ===========================================================================
TRUNCATE TABLE sellers;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/sellers_clean.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);


-- ===========================================================================
-- 4. ORDERS
-- ===========================================================================
-- Source file : data/cleaned/orders_enriched.csv
-- Note        : Includes engineered columns from Phase 3 preprocessing.
--               NULL timestamps come through as empty strings "" which MySQL
--               treats as NULL for DATETIME columns.
-- Note        : is_late is True/False -> 1/0
-- ===========================================================================
TRUNCATE TABLE orders;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/orders_enriched.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    purchase_year,
    purchase_month,
    purchase_day,
    purchase_weekday,
    purchase_hour,
    year_month,
    delivery_duration_days,
    estimated_delivery_days,
    delivery_delay_days,
    is_late,
    carrier_handling_days
);


-- ===========================================================================
-- 5. ORDER ITEMS
-- ===========================================================================
-- Source file : data/cleaned/order_items_clean.csv
-- ===========================================================================
TRUNCATE TABLE order_items;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/order_items_clean.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
);


-- ===========================================================================
-- 6. PAYMENTS
-- ===========================================================================
-- Source file : data/cleaned/order_payments_clean.csv
-- ===========================================================================
TRUNCATE TABLE payments;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/order_payments_clean.csv'
INTO TABLE payments
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
);


-- ===========================================================================
-- 7. REVIEWS
-- ===========================================================================
-- Source file : data/cleaned/order_reviews_clean.csv
-- Note        : review_comment_title and review_comment_message may be empty.
--               MySQL stores empty CSV fields as empty string ""; we convert
--               them to NULL using a SET clause.
-- ===========================================================================
TRUNCATE TABLE reviews;

LOAD DATA LOCAL INFILE
    'C:/Users/USER/OneDrive/Documents/E-Commerce Sales & Customer Analytics with AI/data/cleaned/order_reviews_clean.csv'
INTO TABLE reviews
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    review_id,
    order_id,
    review_score,
    @title,
    @message,
    review_creation_date,
    review_answer_timestamp
)
SET
    -- Convert empty strings to NULL for the optional text columns
    review_comment_title   = NULLIF(@title,   ''),
    review_comment_message = NULLIF(@message, '');


-- ===========================================================================
-- Re-enable foreign key checks
-- ===========================================================================
SET FOREIGN_KEY_CHECKS = 1;


-- ===========================================================================
-- QUICK VERIFICATION
-- ===========================================================================
-- Run these SELECT statements after loading to check the row counts.

SELECT
    'customers'   AS table_name, COUNT(*) AS row_count FROM customers   UNION ALL
SELECT 'products',    COUNT(*) FROM products    UNION ALL
SELECT 'sellers',     COUNT(*) FROM sellers     UNION ALL
SELECT 'orders',      COUNT(*) FROM orders      UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items UNION ALL
SELECT 'payments',    COUNT(*) FROM payments    UNION ALL
SELECT 'reviews',     COUNT(*) FROM reviews;

-- Expected:
-- customers   : 99,441
-- products    : 32,951
-- sellers     :  3,095
-- orders      : 99,441
-- order_items : 112,650
-- payments    : 103,886
-- reviews     :  98,673
