-- Experiment 6 — CockroachDB — "after" snapshot (run ~60s after node 4 joins)
-- Run: cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 03_after.sql

SET allow_unsafe_internals = true;

-- Same query as 01_before.sql — now expect 4 rows.
SELECT lease_holder, count(*) FROM crdb_internal.ranges
GROUP BY lease_holder ORDER BY lease_holder;

-- Unchanged total confirms this is rebalancing, not splitting.
SELECT count(*) AS total_ranges FROM crdb_internal.ranges;

-- Must still be 0 throughout: no range ever dropped below 3 replicas.
SELECT count(*) FILTER (WHERE array_length(replicas, 1) < 3) AS under_replicated
FROM crdb_internal.ranges;

-- The slower signal — physical replica placement — is easiest to read in
-- the DB Console's Replicas column. Screenshot it:
--   results/screenshots/exp6_crdb_rebalance.png
