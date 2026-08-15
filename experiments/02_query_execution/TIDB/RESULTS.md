# Experiment 2 — Results — TiDB

## Measured

| Property | Value |
|---|---|
| Plan-tree operator | Coprocessor tasks (`cop[tikv]`) |
| Where filtering happens | **Pushed to `cop[tikv]`** — the storage layer |
| **Where aggregation happens** | **Root (`HashAgg_22`) — centralised at the TiDB SQL layer** |
| Join strategy | mix of `HashJoin` and `IndexJoin` / `IndexHashJoin` |
| FK columns auto-indexed? | **Yes** — `index:fk_2(product_id)`, visible directly in the plan |
| Missing-index advice in the plan | none surfaced |
| Advisor recommendation (`RECOMMEND INDEX`) | `idx_region` on `customers(region)`, estimated improvement **3.91%** |
| Execution time (single run) | 77.9 ms |
| Rows scanned | ~28,919 total across scans |
| Intermediate join rows | 3,919 (customers/orders stage) |
| Distribution actually observed | filter pushdown only; join and aggregation centralised |

Raw output: `experiments/02_query_execution/exp2_tidb_plan_explain.txt`,
`exp2_tidb_plan_explain_analyze.txt`, `exp2_tidb_index_advice.txt`.

## The finding: real pushdown of the scan, centralised aggregation

TiDB genuinely distributes the *scan* work — `Selection` operators run at
`cop[tikv]`, on the storage nodes. But `HashAgg_22`, the actual
`SUM`/`GROUP BY`, runs at `task: root`: the coprocessor results are gathered
back to the single TiDB SQL node and aggregated there.

No `mpp[tiflash]` appears anywhere, which is correct — MPP requires a
TiFlash replica, and these tables have none at this point. Experiment 8
enables TiFlash on the same tables and the aggregation shape changes
completely.

## The advisor disagreement

TiDB's advisor recommended `customers(region)` — a column that appears only
in `GROUP BY` / `ORDER BY`, never in the `WHERE` clause — at an estimated
**3.91%** improvement. CockroachDB and Spanner both independently
recommended `products(category, rating)` instead, with Spanner quantifying a
**3.88x** improvement.

Two honest caveats on reading this as a disagreement:

- The advisor's `reason` field ("appear[s] in Equal or Range Predicate
  clause(s)") is imprecisely worded for a `GROUP BY` column, but the
  documented behaviour does consider `GROUP BY`/`ORDER BY` columns as
  candidates — so the logic is sound even though the generated explanation
  text is loose.
- Only one row was returned. It is possible `products(category, rating)` was
  evaluated and simply ranked lower by TiDB's cost model rather than never
  considered. Not independently re-verified.

Either way it is a genuine three-way divergence on which fix an automated
advisor considers highest priority, over identical schema, data and query.
