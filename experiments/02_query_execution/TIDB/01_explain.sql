-- Experiment 2 — TiDB — query execution plan
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_explain.sql
--
-- Read the `task` column: cop[tikv] = pushed to the storage layer,
-- root = centralised at the TiDB SQL layer. mpp[tiflash] would mean the
-- columnar MPP engine, which is Experiment 8, not this one.

EXPLAIN ANALYZE
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

EXPLAIN FORMAT='verbose'
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

-- The result itself, for the cross-engine correctness check.
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;
