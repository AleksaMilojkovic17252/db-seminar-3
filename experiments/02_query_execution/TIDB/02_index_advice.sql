-- Experiment 2 — TiDB — index advisor cross-check
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 02_index_advice.sql
--
-- RECOMMEND INDEX was added in TiDB v8.5.0. The query text must be passed
-- as a single quoted string, so it is flattened onto one line here.

RECOMMEND INDEX RUN FOR "SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value FROM orders o JOIN customers c ON o.customer_id = c.id JOIN order_items oi ON oi.order_id = o.id JOIN products p ON oi.product_id = p.id WHERE p.category = 'Electronics' AND p.rating >= 4 GROUP BY c.region ORDER BY c.region";
