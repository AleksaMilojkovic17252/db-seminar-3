# Experiment 2 — Results — Spanner Omni

## Measured (RF=1, original)

| Property | Value |
|---|---|
| Plan-tree operator | Distributed Union / Distributed Cross Apply |
| Where filtering happens | pushed into nested `Distributed Union` / `Filter Scan` |
| **Where aggregation happens** | **Two-phase: local partial `SUM` per batch (plan node 111), then a global `SUM` combining them (plan node 2)** |
| Join strategy | `Cross Apply` only — nested-loop/index-join, **no hash join anywhere** |
| FK columns auto-indexed? | Yes (`IDX_order_items_product_id_...`) |
| Missing-index advice | `products(category, rating)`, quantified: **3.88x improvement factor** |
| Execution time (single run) | 45 ms |
| Rows scanned | 20,676 |
| `remote_server_calls` | `0/0` |

## Measured (RF=3 redo, 2026-07-29)

| | RF=1 (original) | RF=3 (redo) |
|---|---|---|
| `remote_server_calls` | `0/0` | **`7/7`** |
| `rows_scanned` | 20,676 | 20,676 (identical) |
| `rows_returned` | 3 | 3 (identical) |
| `elapsed_time` | 45 ms | 104 ms |
| Result values | eu-west / us-east / us-west, ~$0.98–1.05M each | same three regions, same values: eu-west $1,053,621.02 / us-east $994,522.88 / us-west $983,142.46 |

Raw output: `exp2_spanner_plan.txt`, `exp2_spanner_plan.json` (RF=1);
`exp2_spanner_multi_plan.txt` (RF=3).

## The finding: the only engine that distributes the aggregation itself

Spanner is the one of the three that pushes down more than the scan. Plan
node 111 computes a partial `SUM` per batch; plan node 2 is the global
aggregate combining those partials into the final per-region total. That is
genuine two-phase distributed aggregation, visible directly in the plan
JSON rather than inferred. CockroachDB and TiDB both gather results back to
a single node before aggregating.

## Why the redo mattered

At RF=1, `remote_server_calls: 0/0` *proved* that nothing crossed a network
boundary. The distributed-execution **shape** of the plan was real, but the
distribution itself was never exercised — so the original write-up had to
hedge that Spanner "would execute it the same way" on multi-server hardware,
and flagged that hedge as untested.

Re-running the identical query at RF=3 turns the hedge into a measurement:
7 real cross-server calls, the same two `Aggregate` nodes at equivalent
structural positions, the same 20,676 rows scanned, the same correct
result. The ~2.3x execution-time increase (45 ms → 104 ms) is consistent
with paying for seven real network round-trips that RF=1 could not have
incurred by construction.

The rest of Experiment 2 — the index-advisor divergence in particular — was
**not** re-verified at RF=3.

## Cross-engine correctness check

CockroachDB and TiDB both report exactly **3,919** intermediate joined rows
at the equivalent stage, and all three engines return the same three regions
summing to roughly $3.03M. The ported queries are behaviourally equivalent,
not merely syntactically similar.
