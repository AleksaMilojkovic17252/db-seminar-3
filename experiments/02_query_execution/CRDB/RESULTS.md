# Experiment 2 — Results — CockroachDB

## Measured

| Property | Value |
|---|---|
| Plan-tree operator | DistSQL processors (lookup joins + one hash join) |
| Where filtering happens | Root — single node |
| **Where aggregation happens** | **Root, single node — not distributed** |
| Join strategy | mix of lookup joins (on PK) and one hash join |
| FK columns auto-indexed? | **No** — the optimizer only recommends |
| Missing-index advice | 2 recommendations: `order_items(product_id)` and `products(category, rating)` |
| Execution time (single run) | 85 ms |
| Rows scanned / decoded | 132,331 (5.9 MiB, 5 gRPC calls) |
| Intermediate join rows | 3,919 |
| Distribution actually observed | **none** |

Raw output: `experiments/02_query_execution/exp2_crdb_plan_explain.txt`,
`exp2_crdb_plan_explain_analyze.txt`.

## The finding: `distribution: full` is a capability, not a description

The plan header claims `distribution: full`. Every single operator —
`sort`, `group`, every `lookup join`, the `hash join`, every `scan` — is
annotated `sql nodes: n2` / `regions: us-east`. The entire query, join and
aggregation both, executed on one node.

This is not a contradiction, and it is not a bug. It follows directly from
Experiment 1: all four tables live in single ranges, and those ranges' lease
holders happened to concentrate on node 2. There was nothing to distribute.
Full distribution *capability* is not the same as *actual* distributed
execution, and a plan header alone will not tell you which you got.

## Index advice — one half of a three-way divergence

CockroachDB's advisor flagged `products(category, rating)`. Spanner's
advisor independently flagged **the same index**, without either engine
knowing about the other. TiDB's advisor recommended something else entirely
(`customers(region)`). See `../TIDB/RESULTS.md` and `../SPANNER/RESULTS.md`.
