-- Experiment 6 — CockroachDB — "before" snapshot
-- Run: cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_before.sql

SET allow_unsafe_internals = true;

-- Lease holders per node: the fast-moving signal (query routing).
SELECT lease_holder, count(*) FROM crdb_internal.ranges
GROUP BY lease_holder ORDER BY lease_holder;

-- Total ranges, so we can tell rebalancing apart from splitting.
SELECT count(*) AS total_ranges FROM crdb_internal.ranges;

-- Health baseline.
SELECT count(*) FILTER (WHERE array_length(replicas, 1) < 3) AS under_replicated
FROM crdb_internal.ranges;
