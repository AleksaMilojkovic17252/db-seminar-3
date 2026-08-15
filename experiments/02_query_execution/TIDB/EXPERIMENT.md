# Experiment 2 — Query Execution — TiDB

## What this experiment does

The query is the same logical statement on all three engines: *total order
value per region, for a product category, rating >= 4* — a four-table join
(`orders` + `customers` + `order_items` + `products`) aggregated by region.
All three dialect variants live in `experiments/02_query_execution/query.sql`.

For TiDB the question is how much work reaches the TiKV coprocessor layer
(`cop[tikv]`) and how much stays centralised at the TiDB SQL layer.

A second part runs TiDB's index advisor (`RECOMMEND INDEX`, new in v8.5.0)
against the same query, for the three-way advisor cross-check.

## Prerequisites

TiDB playground up and seeded. **No TiFlash replica on these tables** — the
plain row-store path is what this experiment measures. TiFlash is enabled
later, in Experiment 8, and produces a visibly different plan.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_explain.sql` | `mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_explain.sql` |
| 2 | `02_index_advice.sql` | `mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 02_index_advice.sql` |

Order matters only in that the advisor output is easier to read on its own;
the two are otherwise independent.

## Artifacts of record

- `experiments/02_query_execution/exp2_tidb_plan_explain.txt`
- `experiments/02_query_execution/exp2_tidb_plan_explain_analyze.txt`
- `experiments/02_query_execution/exp2_tidb_index_advice.txt`
- `results/screenshots/exp2_tidb_plan.png` (Dashboard statement detail)
