-- Experiment 2: Query Execution — one logical query, ported to each dialect.
-- "Total order value per region, for a product category, rating >= 4."
-- Touches customers, orders, order_items, products — one join graph,
-- aggregated by region, so the plan comparison has something to show.

-- === CockroachDB (schema_pg.sql) ===
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

-- === TiDB (schema_mysql.sql) ===
-- Identical to the CockroachDB version; MySQL/TiDB syntax matches here.
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

-- === Spanner Omni (schema_googlesql.sql) ===
-- Only difference: order_items.id is the PARENT order's id (interleaving
-- requirement, see schema_googlesql.sql), not a surrogate key -- so the
-- join condition is `oi.id = o.id`, not `oi.order_id = o.id`.
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;
