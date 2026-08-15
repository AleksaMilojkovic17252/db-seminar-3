-- Experiment 8 — TiDB — the HTAP query, expecting full MPP execution
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 03_htap_query.sql
--
-- Read the `task` column. Every operator should say mpp[tiflash], and
-- there should be TWO HashAggs: a local partial aggregation after a
-- HashPartition exchange, then a final global one combining the partials.

EXPLAIN ANALYZE
SELECT p.category, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
GROUP BY p.category;

-- Screenshot the Dashboard statement detail:
--   results/screenshots/exp8_tidb_htap_plan.png
