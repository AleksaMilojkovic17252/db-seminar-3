-- Experiment 1 — CockroachDB — data distribution for `orders`
-- Run: cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_ranges.sql
--
-- NOTE: the SET below is session-scoped and gates every crdb_internal read
-- (new in v25.4+, off by default for all users, audit-logged when enabled).
-- It must be in the SAME session as the query underneath it.

SET allow_unsafe_internals = true;

-- 1. The headline number: how many ranges does `orders` occupy?
SHOW RANGES FROM TABLE orders;

-- 2. The same range, with replica placement and lease holder.
--    (A bare `SELECT ... FROM crdb_internal.ranges LIMIT 20` is useless here:
--     with no filter, rows come back in key order and system/meta ranges fill
--     all 20 slots long before the key space reaches /Table/106 = orders.)
SELECT range_id, start_pretty, end_pretty, lease_holder,
       replicas, replica_localities, voting_replicas
FROM crdb_internal.ranges
WHERE start_pretty LIKE '%/Table/106%' OR range_id = 83;

-- 3. Cluster-wide lease-holder distribution, for the Experiment 6 baseline.
SELECT lease_holder, count(*) FROM crdb_internal.ranges GROUP BY lease_holder ORDER BY lease_holder;
