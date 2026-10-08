-- =============================================================================
-- schema.sql
-- =============================================================================
-- Project : E-Commerce Sales & Customer Analytics with AI
-- Phase   : 5 -- SQL Database Creation
-- Dataset : Brazilian E-Commerce Public Dataset by Olist
--
-- PURPOSE
-- -------
-- Creates the olist_ecommerce database and all seven tables needed for
-- business analysis, dashboards, and machine-learning feature queries.
--
-- HOW TO RUN
-- ----------
--   mysql -u root -p < sql/schema.sql
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. One table per real-world entity (customers, products, sellers ...).
-- 2. Primary keys are the original Olist UUIDs (VARCHAR 36) so they match
--    the cleaned CSV files exactly -- no surrogate integer keys needed.
-- 3. Foreign keys are declared so MySQL enforces referential integrity and
--    makes the join relationships self-documenting.
-- 4. All timestamp columns use DATETIME (MySQL native type).
-- 5. Monetary columns use DECIMAL(10,2) -- exact arithmetic, no float errors.
-- 6. The schema is intentionally flat (no extra normalisation tables) to keep
--    queries beginner-friendly.
--
-- TABLE LOAD ORDER (respects FK dependencies)
-- --------------------------------------------
--   1. customers   (no FK dependencies)
--   2. products    (no FK dependencies)
--   3. sellers     (no FK dependencies)
--   4. orders      (FK -> customers)
--   5. order_items (FK -> orders, products, sellers)
--   6. payments    (FK -> orders)
--   7. reviews     (FK -> orders)
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Create and select the database
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS olist_ecommerce
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE olist_ecommerce;


-- ===========================================================================
-- TABLE 1: customers
-- ===========================================================================
-- PURPOSE  : Master table of all customer records.
--            One row per OLIST customer_id (which is order-scoped).
--            Use customer_unique_id to identify real unique buyers.
--
-- PRIMARY KEY  : customer_id (UUID assigned per order by Olist)
-- FOREIGN KEYS : none (this is a root / parent table)
-- RELATIONSHIP : One customer_id -> one row in orders
-- ===========================================================================
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id             VARCHAR(36)  NOT NULL,
    customer_unique_id      VARCHAR(36)  NOT NULL,   -- true unique buyer identity
    customer_zip_code_prefix CHAR(5)     NOT NULL,   -- 5-digit zip prefix (string, not int)
    customer_city           VARCHAR(100) NOT NULL,
    customer_state          CHAR(2)      NOT NULL,   -- 2-letter Brazilian state code

    PRIMARY KEY (customer_id),

    -- Index on unique_id because RFM queries group by this column
    INDEX idx_customer_unique_id (customer_unique_id),
    INDEX idx_customer_state     (customer_state)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 2: products
-- ===========================================================================
-- PURPOSE  : Product catalogue. One row per product sold on the platform.
--
-- PRIMARY KEY  : product_id (UUID)
-- FOREIGN KEYS : none (root table)
-- RELATIONSHIP : One product -> many order_items rows
--
-- NOTE: Column names keep the original Olist typo ("lenght" not "length") so
--       the data loads without remapping.
-- ===========================================================================
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    product_id                    VARCHAR(36)   NOT NULL,
    product_category_name         VARCHAR(100)  NULL,   -- Portuguese name (may be NULL for 610 incomplete)
    product_category_name_english VARCHAR(100)  NULL,   -- English translation (may be NULL for same 610)
    product_name_lenght           SMALLINT      NULL,   -- character count of product name
    product_description_lenght    INT           NULL,   -- character count of product description
    product_photos_qty            TINYINT       NULL,   -- number of listing photos
    product_weight_g              DECIMAL(8,2)  NULL,   -- weight in grams
    product_length_cm             DECIMAL(6,2)  NULL,
    product_height_cm             DECIMAL(6,2)  NULL,
    product_width_cm              DECIMAL(6,2)  NULL,
    is_incomplete                 BOOLEAN       NOT NULL DEFAULT FALSE,
                                                        -- TRUE for 610 products with all-null descriptive cols

    PRIMARY KEY (product_id),
    INDEX idx_product_category (product_category_name_english)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 3: sellers
-- ===========================================================================
-- PURPOSE  : Seller location information.
--
-- PRIMARY KEY  : seller_id (UUID)
-- FOREIGN KEYS : none (root table)
-- RELATIONSHIP : One seller -> many order_items rows
-- ===========================================================================
DROP TABLE IF EXISTS sellers;

CREATE TABLE sellers (
    seller_id               VARCHAR(36)  NOT NULL,
    seller_zip_code_prefix  CHAR(5)      NOT NULL,
    seller_city             VARCHAR(100) NOT NULL,
    seller_state            CHAR(2)      NOT NULL,

    PRIMARY KEY (seller_id),
    INDEX idx_seller_state (seller_state)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 4: orders
-- ===========================================================================
-- PURPOSE  : The central/spine table. Every transaction starts here.
--            Also stores the engineered delivery-metric columns from
--            Phase 3 preprocessing so they are query-ready in SQL.
--
-- PRIMARY KEY  : order_id (UUID)
-- FOREIGN KEYS : customer_id -> customers.customer_id
-- RELATIONSHIP : Many orders -> one customer
--                One order   -> many order_items, payments, reviews
-- ===========================================================================
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id                      VARCHAR(36)  NOT NULL,
    customer_id                   VARCHAR(36)  NOT NULL,   -- FK to customers
    order_status                  VARCHAR(20)  NOT NULL,

    -- Raw timestamps (all stored as DATETIME; NULL allowed for undelivered orders)
    order_purchase_timestamp      DATETIME     NOT NULL,
    order_approved_at             DATETIME     NULL,
    order_delivered_carrier_date  DATETIME     NULL,
    order_delivered_customer_date DATETIME     NULL,
    order_estimated_delivery_date DATETIME     NOT NULL,

    -- Engineered date parts (from Phase 3 preprocessing)
    purchase_year                 SMALLINT     NULL,   -- e.g. 2017
    purchase_month                TINYINT      NULL,   -- 1-12
    purchase_day                  TINYINT      NULL,   -- 1-31
    purchase_weekday              TINYINT      NULL,   -- 0=Mon ... 6=Sun
    purchase_hour                 TINYINT      NULL,   -- 0-23
    `year_month`                  VARCHAR(7)   NULL,   -- 'YYYY-MM' string for grouping

    -- Engineered delivery metrics (from Phase 3 preprocessing)
    delivery_duration_days        DECIMAL(6,1) NULL,   -- actual days purchase -> delivery
    estimated_delivery_days       DECIMAL(6,1) NULL,   -- promised days purchase -> estimate
    delivery_delay_days           DECIMAL(6,1) NULL,   -- actual - estimate (positive = late)
    is_late                       BOOLEAN      NULL,   -- TRUE if arrived after estimate
    carrier_handling_days         DECIMAL(6,1) NULL,   -- days purchase -> carrier handoff

    PRIMARY KEY (order_id),

    -- FK to customers (enforces no orphaned orders)
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Indexes for common filter/join patterns
    INDEX idx_orders_customer_id   (customer_id),
    INDEX idx_orders_status        (order_status),
    INDEX idx_orders_year_month    (`year_month`),
    INDEX idx_orders_purchase_ts   (order_purchase_timestamp)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 5: order_items
-- ===========================================================================
-- PURPOSE  : Line items within each order. One row per product per order.
--            An order with 3 products has 3 rows here.
--
-- PRIMARY KEY  : composite (order_id, order_item_id)
--                order_item_id is the sequence number within the order (1, 2, 3...)
-- FOREIGN KEYS : order_id   -> orders.order_id
--                product_id -> products.product_id
--                seller_id  -> sellers.seller_id
-- RELATIONSHIP : Many items -> one order, one product, one seller
-- ===========================================================================
DROP TABLE IF EXISTS order_items;

CREATE TABLE order_items (
    order_id            VARCHAR(36)   NOT NULL,   -- FK to orders
    order_item_id       TINYINT       NOT NULL,   -- sequence: 1, 2, 3 ... (max 21)
    product_id          VARCHAR(36)   NOT NULL,   -- FK to products
    seller_id           VARCHAR(36)   NOT NULL,   -- FK to sellers
    shipping_limit_date DATETIME      NULL,        -- seller's deadline to hand to carrier
    price               DECIMAL(10,2) NOT NULL,   -- item price in BRL
    freight_value       DECIMAL(10,2) NOT NULL,   -- shipping cost in BRL

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id)   REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
        -- CASCADE: if an order is deleted, its items go too

    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id)  REFERENCES sellers(seller_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    INDEX idx_items_product_id (product_id),
    INDEX idx_items_seller_id  (seller_id)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 6: payments
-- ===========================================================================
-- PURPOSE  : Payment details per order. One order can have multiple rows
--            (e.g. credit card + voucher combo), so there is NO single-column
--            primary key. The composite (order_id, payment_sequential) is unique.
--
-- PRIMARY KEY  : composite (order_id, payment_sequential)
-- FOREIGN KEYS : order_id -> orders.order_id
-- RELATIONSHIP : Many payments -> one order
-- ===========================================================================
DROP TABLE IF EXISTS payments;

CREATE TABLE payments (
    order_id              VARCHAR(36)   NOT NULL,   -- FK to orders
    payment_sequential    TINYINT       NOT NULL,   -- 1 = first method, 2 = second, etc.
    payment_type          VARCHAR(20)   NOT NULL,   -- credit_card | boleto | voucher | debit_card
    payment_installments  TINYINT       NOT NULL,   -- number of monthly installments chosen
    payment_value         DECIMAL(10,2) NOT NULL,   -- amount paid via this method in BRL

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    INDEX idx_payments_type (payment_type)
) ENGINE=InnoDB;


-- ===========================================================================
-- TABLE 7: reviews
-- ===========================================================================
-- PURPOSE  : Customer satisfaction reviews. One row per order (after dedup
--            in Phase 2 cleaning -- we kept the latest review per order).
--
-- PRIMARY KEY  : review_id (UUID assigned by Olist)
-- FOREIGN KEYS : order_id -> orders.order_id
-- RELATIONSHIP : One review -> one order  (1:1 after cleaning)
-- ===========================================================================
DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews (
    review_id               VARCHAR(36)  NOT NULL,
    order_id                VARCHAR(36)  NOT NULL,   -- FK to orders
    review_score            TINYINT      NOT NULL,   -- 1 (worst) to 5 (best)
    review_comment_title    VARCHAR(255) NULL,        -- optional short title
    review_comment_message  TEXT         NULL,        -- optional full comment text
    review_creation_date    DATETIME     NULL,        -- when Olist sent the survey
    review_answer_timestamp DATETIME     NULL,        -- when customer submitted

    PRIMARY KEY (review_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    INDEX idx_reviews_order_id    (order_id),
    INDEX idx_reviews_score       (review_score)
) ENGINE=InnoDB;


-- =============================================================================
-- VERIFICATION QUERY
-- Run this after loading data to confirm row counts match the cleaned CSVs.
-- =============================================================================
/*
SELECT 'customers'   AS table_name, COUNT(*) AS row_count FROM customers   UNION ALL
SELECT 'products'    AS table_name, COUNT(*) AS row_count FROM products    UNION ALL
SELECT 'sellers'     AS table_name, COUNT(*) AS row_count FROM sellers     UNION ALL
SELECT 'orders'      AS table_name, COUNT(*) AS row_count FROM orders      UNION ALL
SELECT 'order_items' AS table_name, COUNT(*) AS row_count FROM order_items UNION ALL
SELECT 'payments'    AS table_name, COUNT(*) AS row_count FROM payments    UNION ALL
SELECT 'reviews'     AS table_name, COUNT(*) AS row_count FROM reviews;

-- Expected results:
-- customers   : 99,441
-- products    : 32,951
-- sellers     :  3,095
-- orders      : 99,441
-- order_items : 112,650
-- payments    : 103,886
-- reviews     :  98,673
*/
