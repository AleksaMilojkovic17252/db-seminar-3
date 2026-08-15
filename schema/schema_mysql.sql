-- Phase 2 logical schema — TiDB (MySQL) dialect.
-- Column names/order are kept identical across schema_pg.sql,
-- schema_mysql.sql, and schema_googlesql.sql so experiments/02_query_execution/query.sql
-- can be ported verbatim across engines.
--
-- NOTE: TiDB does not pre-create a `test` database the way some old MySQL
-- installs did, so a plain `mysql -u root < schema_mysql.sql` with no
-- database selected fails with "No database selected." This file creates
-- its own database explicitly.

CREATE DATABASE IF NOT EXISTS seminar;
USE seminar;

-- === Banking (Exp 3 transactions, Exp 7 benchmark) ===

CREATE TABLE accounts (
    id      BIGINT PRIMARY KEY AUTO_INCREMENT,
    owner   VARCHAR(100) NOT NULL,
    balance DECIMAL(15,2) NOT NULL,
    region  VARCHAR(50) NOT NULL
);

CREATE TABLE ledger (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    from_acct  BIGINT NOT NULL,
    to_acct    BIGINT NOT NULL,
    amount     DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (from_acct) REFERENCES accounts(id),
    FOREIGN KEY (to_acct) REFERENCES accounts(id)
);

-- === E-commerce (Exp 1 distribution, Exp 2 query execution, Exp 8 HTAP) ===

CREATE TABLE customers (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) NOT NULL,
    region     VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id       BIGINT PRIMARY KEY AUTO_INCREMENT,
    name     VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price    DECIMAL(10,2) NOT NULL,
    rating   DECIMAL(2,1) NOT NULL
);

CREATE TABLE orders (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_id BIGINT NOT NULL,
    order_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total       DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Kept as a single-column id for parity with CockroachDB; on Spanner this
-- table is interleaved under orders instead (see schema_googlesql.sql).
CREATE TABLE order_items (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id   BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity   INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- === Doctors (Exp 4 write-skew) ===
-- ids are seeded explicitly as 1..10 (not auto-increment) so ids 1 and 2
-- can be pinned as the two on-call doctors per the runbook's setup.

CREATE TABLE doctors (
    id      BIGINT PRIMARY KEY,
    name    VARCHAR(100) NOT NULL,
    on_call BOOLEAN NOT NULL DEFAULT FALSE
);
