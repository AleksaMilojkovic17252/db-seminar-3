-- Experiment 6 — TiDB — "after" snapshot
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 03_after.sql

-- Same query as 01_before.sql — now expect a 4th store_id.
SELECT store_id, count(*) FROM information_schema.tikv_region_peers GROUP BY store_id;

SELECT store_id, address, store_state_name FROM information_schema.tikv_store_status;

SELECT count(DISTINCT region_id) AS total_regions FROM information_schema.tikv_region_status;

-- Screenshot: Dashboard -> Cluster Info -> Instances
--   -> results/screenshots/exp6_tidb_regions.png
-- (Key Visualizer does not render usefully at this data scale.)
