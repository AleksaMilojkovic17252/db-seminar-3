-- Phase 2 logical schema — Spanner GoogleSQL dialect.
-- Column names/order are kept identical to schema_pg.sql and schema_mysql.sql
-- so experiments/02_query_execution/query.sql can be ported verbatim across
-- engines, EXCEPT order_items (see note below).
--
-- Apply via the Spanner CLI, e.g.:
--   docker exec -i spanneromni /google/spanner/bin/spanner databases ddl update \
--     --database-name=<db> --ddl-file=/path/to/this/file (or statement-by-statement)
-- Confirm the exact invocation against the Omni quickstart before running.

-- === Banking (Exp 3 transactions, Exp 5 clocks, Exp 7 benchmark) ===

CREATE TABLE accounts (
    id      INT64 NOT NULL,
    owner   STRING(MAX) NOT NULL,
    balance NUMERIC NOT NULL,
    region  STRING(MAX) NOT NULL,
) PRIMARY KEY (id);

CREATE TABLE ledger (
    id         INT64 NOT NULL,
    from_acct  INT64 NOT NULL,
    to_acct    INT64 NOT NULL,
    amount     NUMERIC NOT NULL,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
    CONSTRAINT fk_ledger_from FOREIGN KEY (from_acct) REFERENCES accounts (id),
    CONSTRAINT fk_ledger_to FOREIGN KEY (to_acct) REFERENCES accounts (id),
) PRIMARY KEY (id);

-- === E-commerce (Exp 1 distribution, Exp 2 query execution, Exp 8 standouts) ===

CREATE TABLE customers (
    id         INT64 NOT NULL,
    name       STRING(MAX) NOT NULL,
    email      STRING(MAX) NOT NULL,
    region     STRING(MAX) NOT NULL,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
) PRIMARY KEY (id);

CREATE TABLE products (
    id       INT64 NOT NULL,
    name     STRING(MAX) NOT NULL,
    category STRING(MAX) NOT NULL,
    price    NUMERIC NOT NULL,
    rating   FLOAT64 NOT NULL,
) PRIMARY KEY (id);

CREATE TABLE orders (
    id          INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    order_date  TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true),
    total       NUMERIC NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (id),
) PRIMARY KEY (id);

-- INTERLEAVED child of orders — this is the Exp 8 locality demo (Phase 10):
-- each order's line items are physically co-located with the parent order,
-- so a parent-child join becomes a single-server Distributed Union with no
-- cross-server hop.
--
-- Spanner's interleaving rule is stricter than "parent key as a prefix": the
-- child's leading primary-key column must have the SAME NAME (and type) as
-- the parent's key column, not just point at it by value. orders' PK column
-- is named `id`, so order_items' first PK column must also be named `id`
-- (it holds the parent order's id) -- attempting `order_id` here fails DDL
-- application with "references parent key column id at incorrect position 1".
-- The item's own local sequence number within the order is therefore named
-- `item_id` instead. Mapping vs. the other two dialects: Spanner's
-- order_items.id == CRDB/TiDB's order_items.order_id (the parent FK), and
-- Spanner's order_items.item_id == CRDB/TiDB's order_items.id (the item's
-- own surrogate key). Documented as an intentional cross-dialect asymmetry
-- in experiments/08_standouts/exp8_compatibility.md, not an oversight.
CREATE TABLE order_items (
    id         INT64 NOT NULL,
    item_id    INT64 NOT NULL,
    product_id INT64 NOT NULL,
    quantity   INT64 NOT NULL,
    unit_price NUMERIC NOT NULL,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (id),
) PRIMARY KEY (id, item_id),
  INTERLEAVE IN PARENT orders ON DELETE CASCADE;

-- === Doctors (Exp 4 write-skew) ===
-- ids are seeded explicitly as 1..10 so ids 1 and 2 can be pinned as the
-- two on-call doctors per the runbook's setup.

CREATE TABLE doctors (
    id      INT64 NOT NULL,
    name    STRING(MAX) NOT NULL,
    on_call BOOL NOT NULL,
) PRIMARY KEY (id);
