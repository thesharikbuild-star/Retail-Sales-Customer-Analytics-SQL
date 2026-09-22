-- ============================================================
-- PROJECT: Retail Sales & Customer Analytics
-- FILE: 01_schema.sql
-- PURPOSE: Table definitions
-- DIALECT: SQLite-compatible SQL, using standard relational SQL constructs.
-- TESTED: SQLite 3.45
-- Notes are included where PostgreSQL/MySQL syntax may differ.
-- ============================================================

DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS customers;

-- ------------------------------------------------------------
-- CUSTOMERS
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    customer_name   TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    region          TEXT NOT NULL,          -- North, South, East, West
    signup_date     DATE NOT NULL
);

-- ------------------------------------------------------------
-- CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id     INTEGER PRIMARY KEY,
    category_name   TEXT NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- PRODUCTS
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id      INTEGER PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category_id     INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- ------------------------------------------------------------
-- ORDERS  (one row per order/transaction header)
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id        INTEGER PRIMARY KEY,
    customer_id     INTEGER NOT NULL,
    order_date      DATE NOT NULL,
    order_status    TEXT NOT NULL DEFAULT 'Completed',  -- Completed, Cancelled, Returned
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ------------------------------------------------------------
-- ORDER_ITEMS  (line items â€” one row per product per order)
-- Added beyond the brief's table list because real-world orders
-- contain multiple products; this is what makes "top products",
-- "category performance" etc. answerable with a JOIN instead of
-- forcing one-product-per-order. Standard in every real schema.
-- ------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id   INTEGER PRIMARY KEY,
    order_id        INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,   -- price at time of sale
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ------------------------------------------------------------
-- PAYMENTS
-- ------------------------------------------------------------
CREATE TABLE payments (
    payment_id      INTEGER PRIMARY KEY,
    order_id        INTEGER NOT NULL,
    payment_date    DATE NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    payment_method  TEXT NOT NULL,   -- Credit Card, UPI, Net Banking, COD
    payment_status  TEXT NOT NULL DEFAULT 'Success',  -- Success, Failed, Refunded
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Helpful indexes (real interviewers ask about these too)
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_date       ON orders(order_date);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_prod  ON order_items(product_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_payments_order    ON payments(order_id);
