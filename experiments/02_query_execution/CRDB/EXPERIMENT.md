# Experiment 2 — Query Execution — CockroachDB

## What this experiment does

The query is the same logical statement on all three engines: *total order
value per region, for a product category, rating >= 4* — a four-table join
(`orders` + `customers` + `order_items` + `products`) aggregated by region.
All three dialect variants live in `experiments/02_query_execution/query.sql`.

For CockroachDB the question is where the plan places each operator: does
`distribution: full` in the plan header mean the work actually spread across
nodes?

## Prerequisites

3-node cluster up and seeded. See `docs/daily_startup.md`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_explain.sql` | `cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_explain.sql` |

Run `EXPLAIN (VERBOSE)` before `EXPLAIN ANALYZE` — the verbose form is the
artifact of record here (see the gotcha), and running it first means the
index recommendations appear before the timing output rather than buried
under it.

## Gotcha that cost time

`EXPLAIN ANALYZE (DISTSQL)` emits a URL to the **external** DistSQL diagram
viewer at `cockroachdb.github.io/distsqlplan`. That viewer is unmaintained
upstream and renders blank — this is the runbook's own troubleshooting item
T-12. The fallback is `EXPLAIN (VERBOSE)` text, which the runbook already
treats as the primary artifact because diagram screenshots are unreadable at
print size. **There is no CockroachDB plan screenshot in this project**, and
that absence is documented rather than hidden.

## Artifacts of record

- `experiments/02_query_execution/exp2_crdb_plan_explain.txt`
- `experiments/02_query_execution/exp2_crdb_plan_explain_analyze.txt`
