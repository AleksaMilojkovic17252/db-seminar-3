-- Experiment 6 — TiDB — "before" snapshot
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_before.sql

-- Peer count per store: the rebalancing signal.
SELECT store_id, count(*) FROM information_schema.tikv_region_peers GROUP BY store_id;

-- Store inventory, for comparison after scale-out.
SELECT store_id, address, store_state_name FROM information_schema.tikv_store_status;

-- Total regions, to tell rebalancing apart from splitting.
SELECT count(DISTINCT region_id) AS total_regions FROM information_schema.tikv_region_status;
