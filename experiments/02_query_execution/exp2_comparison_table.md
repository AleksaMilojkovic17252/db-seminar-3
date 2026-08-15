# Experiment 2 — Query Execution: Comparison

Query: "total order value per region, for a product category, rating >= 4" —
one join graph (`orders` + `customers` + `order_items` + `products`), ported
verbatim (modulo the documented `order_items` column-name difference on
Spanner) to all three dialects. See `query.sql`.

| | CockroachDB | TiDB | Spanner Omni |
|---|---|---|---|
| **Plan-tree operator (runbook's "push computation to the data" concept)** | DistSQL processors (lookup/hash joins) | Coprocessor tasks (`cop[tikv]`) | Distributed Union / Distributed Cross Apply |
| **Where filtering happens** | Root (single node, n2) | Pushed to `cop[tikv]` (storage layer) | Pushed into nested `Distributed Union`/`Filter Scan` |
| **Where aggregation happens** | Root, single node — not distributed | Root (`HashAgg`) — not distributed | **Two-phase: local partial `SUM` per batch, then a global `SUM` combining them** |
| **Join strategy** | Mix: lookup joins (PK) + 1 hash join | Mix: `HashJoin` + `IndexJoin`/`IndexHashJoin` | Only `Cross Apply` (nested-loop/index-join) — no hash join anywhere |
| **FK columns auto-indexed?** | No (optimizer only *recommends*) | Yes (`fk_2(product_id)`) | Yes (`IDX_order_items_product_id_...`) |
| **Missing-index advice given** | 2 recommendations: `order_items(product_id)`, `products(category,rating)` | none surfaced in this plan | `products(category,rating)`, quantified: **3.88x improvement factor** |
| **Execution time (single run, not a benchmark — R3)** | 85ms | 77.9ms | 45ms |
| **Rows scanned/decoded** | 132,331 (5.9 MiB, 5 gRPC calls) | ~28,919 total across scans | 20,676 |
| **Intermediate join rows** | 3,919 | 3,919 (customers/orders join stage) | not directly comparable field, but same result set |
| **Distribution actually observed** | None — all operators ran on node n2 despite `distribution: full` | Filter pushdown only; join+agg centralized | Local+global aggregation is real distribution; `remote_server_calls: 0/0` (single-server, RF=1) |

## The headline finding: aggregation locality

The runbook asks specifically where aggregation happens in each plan, because
that's the substantive architectural difference once you strip away the
"push computation to the data" marketing framing all three vendors share.

- **CockroachDB**: despite the plan header claiming `distribution: full`,
  every single operator (`sort`, `group`, every `lookup join`, the
  `hash join`, every `scan`) is annotated `sql nodes: n2` / `regions: us-east`.
  The whole query — join *and* aggregation — executed on one node. This
  connects directly to Experiment 1: all four tables live in single ranges,
  and their lease holders happened to concentrate on node 2, so there was
  nothing to distribute.
- **TiDB**: filtering (`Selection`) is genuinely pushed to the TiKV
  coprocessor layer (`cop[tikv]`), which is real distribution of the *scan*
  work. But `HashAgg_22` — the actual `SUM`/`GROUP BY` — runs at
  `task: root`, i.e. centralized at the TiDB SQL layer after coprocessor
  results are gathered. No `mpp[tiflash]` appears; that requires a TiFlash
  replica, which isn't configured on these tables (that's Experiment 8).
- **Spanner Omni**: the only one of the three that distributes the
  aggregation itself, not just the scan. Plan node 111 is a `Local`
  aggregate computing a partial `SUM` per batch; plan node 2 is the `Global`
  aggregate combining those partials into the final per-region total. This
  is genuine two-phase distributed aggregation, visible directly in the
  plan JSON, not inferred.

Caveat for the paper (R1/R2): Spanner *originally* ran single-server here,
and `"remote_server_calls": "0/0"` in its own query stats *proved* nothing
actually crossed a network boundary in that run — the distributed-execution
*shape* of the plan was real, but the *distribution* itself wasn't
exercised on that hardware.

**This has since been directly confirmed (2026-07-29).** The identical
query, run via `--query-mode=PROFILE` against the redone 3-root-server
deployment (`seminar-multiserver`, `docs/spanner_multiserver_setup.md`),
shows:

| | RF=1 (original) | RF=3 (redo) |
|---|---|---|
| `remote_server_calls` | `0/0` | **`7/7`** |
| `rows_scanned` | 20,676 | 20,676 (identical) |
| `rows_returned` | 3 | 3 (identical) |
| `elapsed_time` | 45ms | 104ms |
| Result values | eu-west/us-east/us-west ~$0.98-1.05M each | same three regions, same values (eu-west $1,053,621.02 / us-east $994,522.88 / us-west $983,142.46) |

Same plan shape (the same two `Aggregate` plan nodes at equivalent
structural positions, confirming the local-partial + global-combine
two-phase shape survives unchanged), identical row-scan efficiency and
identical correct result — but now genuinely crossing server boundaries 7
times where before there was structurally nothing to cross. The ~2.3x
execution-time increase (45ms → 104ms) is consistent with paying for those
7 real network round-trips that RF=1 could not have incurred by
construction. This is no longer an inference — it's a measured result: the
"Spanner would execute it the same way on a multi-server deployment" claim
from the original write-up is now directly confirmed rather than asserted.

## Cross-engine correctness check

CockroachDB and TiDB's plans both report **exactly 3,919** intermediate
joined rows at the equivalent join stage, and all three engines return the
same three regions with sums in the same range (~$0.98M–$1.05M per region,
summing to ~$3.03M). This corroborates that the ported queries are
behaviorally equivalent across dialects, not just syntactically similar —
worth stating explicitly rather than assuming from matching row counts alone.

## Index recommendations: two agree, one diverges

CockroachDB's `EXPLAIN (VERBOSE)` index advisor and Spanner's `queryAdvice`
block **independently** flagged the same missing index —
`products(category, rating)` — without either being told about the other's
recommendation. Spanner additionally quantifies the expected win: a 3.88x
improvement factor.

TiDB's advisor (`RECOMMEND INDEX RUN FOR "..."`, added in v8.5.0) disagrees.
Run against the identical query, it recommended `idx_region` on
`customers(region)` instead — a column that appears only in `GROUP BY`/
`ORDER BY`, not in the `WHERE` clause — with a quantified improvement of
just **3.91%**, an order of magnitude smaller than Spanner's estimate for
the products index. Its `reason` field ("appear[s] in Equal or Range
Predicate clause(s)") is imprecisely worded for a `GROUP BY` column, though
the advisor's documented behavior does say it considers `GROUP BY`/`ORDER BY`
columns as candidates, so the recommendation logic is sound even if the
auto-generated explanation text is loose. Only one row was returned, so it's
possible `products(category, rating)` was evaluated and simply ranked lower
by TiDB's cost model rather than never considered — not independently
re-verified here.

So this is **not** a three-way convergence — it's a genuine three-way
divergence on which fix an automated advisor considers highest-priority,
despite all three operating over the same schema, the same data, and the
same query. That's arguably a more interesting result for the paper than
agreement would have been: it says something concrete about how differently
each engine's cost model weighs `WHERE`-clause selectivity against
`GROUP BY`/`ORDER BY` cost, not just that "indexes matter."

## Gotchas hit while running this experiment (worth keeping for the paper's methodology section)

- **CockroachDB's external DistSQL diagram viewer (`cockroachdb.github.io/distsqlplan`)
  is unmaintained and rendered blank.** This is exactly the runbook's own
  troubleshooting item T-12; fell back to `EXPLAIN (VERBOSE)` text, which
  the runbook already treats as the primary artifact anyway (screenshots of
  these diagrams are "usually unreadable at print size").
- **Spanner's CLI (this Omni beta) fails to parse multi-line `--sql` values**
  with a generic `Error: failed to build statement: invalid statement` —
  the exact same query worked immediately once flattened to one line. Not a
  SQL problem; a CLI-parsing quirk of this Preview build. Every Spanner CLI
  query in this project is written single-line from this point on.

## Artifacts

- `experiments/02_query_execution/query.sql` — all three dialect variants
- `experiments/02_query_execution/exp2_tidb_index_advice.txt` — `RECOMMEND INDEX` output
- `experiments/02_query_execution/exp2_crdb_plan_explain.txt` / `exp2_crdb_plan_explain_analyze.txt`
- `experiments/02_query_execution/exp2_tidb_plan_explain.txt` / `exp2_tidb_plan_explain_analyze.txt`
- `experiments/02_query_execution/exp2_spanner_plan.txt` (full transcript) / `exp2_spanner_plan.json` (extracted plan, PROFILE mode with executionStats) — **RF=1, original**
- `experiments/02_query_execution/exp2_spanner_multi_plan.txt` — identical query re-run against the RF=3 redo (2026-07-29), `remote_server_calls: 7/7`
- `results/screenshots/exp2_tidb_plan.png` (Dashboard statement detail)
- `results/screenshots/exp2_spanner_plan.png` (Query Insights)
- `results/screenshots/exp2_crdb_distsql.png` — not captured (external viewer broken); text plan is the artifact of record for CockroachDB per T-12
