-- Experiment 8 — TiDB — enable TiFlash columnar replicas
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 02_htap_setup.sql
--
-- ALL THREE joined tables need a replica. A genuine MPP join cannot be
-- planned if only one side is available columnar.

ALTER TABLE orders      SET TIFLASH REPLICA 1;
ALTER TABLE order_items SET TIFLASH REPLICA 1;
ALTER TABLE products    SET TIFLASH REPLICA 1;

-- WAIT until every row reads PROGRESS=1 and AVAILABLE=1 before running
-- 03_htap_query.sql. Re-run this query until it does (seconds, at this
-- data scale).
SELECT table_name, replica_count, available, progress
FROM information_schema.tiflash_replica
WHERE table_name IN ('orders', 'order_items', 'products');
