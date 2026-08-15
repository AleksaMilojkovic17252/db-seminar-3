-- Experiment 2 — CockroachDB — query execution plan
-- Run: cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_explain.sql

-- 1. Text plan. THIS is the artifact of record — the DistSQL diagram viewer
--    (cockroachdb.github.io/distsqlplan) is unmaintained and renders blank.
--    Watch two things: the `distribution:` header, and the per-operator
--    `sql nodes:` / `regions:` annotations, which are what actually says
--    where each operator ran.
EXPLAIN (VERBOSE)
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

-- 2. Runtime stats: execution time, rows decoded, gRPC calls, and the
--    automatic missing-index recommendations.
EXPLAIN ANALYZE
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;

-- 3. The result itself, for the cross-engine correctness check.
SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE p.category = 'Electronics' AND p.rating >= 4
GROUP BY c.region
ORDER BY c.region;
