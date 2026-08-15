-- Experiment 1 — TiDB — data distribution for `orders`
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_regions.sql

-- 1. The headline number: how many regions does `orders` occupy?
SHOW TABLE orders REGIONS;

-- 2. Leader store per region.
--    The runbook's `leader_store_id` column does NOT exist in
--    information_schema.tikv_region_status on v8.5.7. Join to
--    tikv_region_peers and filter IS_LEADER instead.
SELECT s.region_id, s.start_key, s.end_key, p.store_id AS leader_store_id
FROM information_schema.tikv_region_status s
JOIN information_schema.tikv_region_peers p ON p.region_id = s.region_id
WHERE p.is_leader = 1
LIMIT 20;

-- 3. Confirm the replicas are spread over all three stores (RF=3 check,
--    and the Experiment 6 "before" baseline).
SELECT store_id, count(*) FROM information_schema.tikv_region_peers GROUP BY store_id;

-- 4. Store health, to confirm three stores are actually Up.
SELECT store_id, address, store_state_name FROM information_schema.tikv_store_status;
