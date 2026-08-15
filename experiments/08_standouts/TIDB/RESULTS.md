# Experiment 8 — Results — TiDB

## Part 1 — HTAP: the plan

With TiFlash replicas on all three tables, **every operator** runs in
`mpp[tiflash]`: both `HashJoin`s (`order_items`⋈`orders`,
`order_items`⋈`products`) and — critically — **both `HashAgg`s**. A local
partial aggregation (`HashAgg_140`, per-partition after an
`ExchangeSender`/`HashPartition` re-shuffle by `category`) is followed by a
final global `HashAgg_143` combining the partials. Only the tiny 8-row
result crosses back to `root`.

Total: **32.5 ms** for a 3-way join and aggregation over 120,000
`order_items` rows.

Full plan: `experiments/08_standouts/exp8_tidb_01.txt`.
Screenshot: `results/screenshots/exp8_tidb_htap_plan.png`.

**This is the same two-phase distributed-aggregation pattern that was
Spanner's standout in Experiment 2.** The difference is what it takes to
get it: Spanner produced it on its normal OLTP-facing path with no special
configuration; TiDB produces it only once TiFlash is enabled and the
optimizer chooses the MPP engine. Experiment 2's plain TiDB plan, with no
TiFlash, centralised the aggregation at `root` instead. HTAP is TiDB's way
of *buying* that capability for OLAP-shaped queries — not something its row
store does by default.

## Part 2 — HTAP: the claim that actually matters

Method: run `point_read` / `point_write` at 16 threads for 20 s, with and
without the analytical query looping concurrently in a second process.

| Workload | Metric | No HTAP load | With concurrent HTAP load | Change |
|---|---|---|---|---|
| `point_read` | ops/sec | 9432.10 | 7024.85 | **−25%** |
| `point_read` | p99 | 4.245 ms | 5.957 ms | **+40%** |
| `point_write` | ops/sec | 2539.95 | 2460.65 | −3% (noise) |
| `point_write` | p99 | 11.630 ms | 11.994 ms | +3% (noise) |

Raw data: `experiments/08_standouts/exp8_tidb_htap_oltp.csv`.

**The write path stays clean; the read path degrades.** Writes go through
TiKV and the Raft path, which the columnar engine does not touch. Reads
compete with the MPP query for the same CPU on a single-laptop deployment
where PD, three TiKV stores, TiFlash, the TiDB node and the benchmark client
all share the same cores.

So the honest version of the finding is: **workload isolation held on the
write path and partially failed on the read path** — and the failure is
plausibly a resource-contention artifact of this deployment rather than an
architectural limit. A real cluster separates TiFlash onto its own nodes,
which is the entire point of the design. Saying "TiDB's HTAP isolation fails"
from this measurement would overclaim.

## Part 3 — SQL compatibility

| Feature | Result |
|---|---|
| Window functions | works |
| CTEs | works |
| `RETURNING` on `UPDATE` | **syntax error** — MySQL/TiDB has no equivalent |
| Foreign key enforcement | rejects, error 1452 |
| Identity columns | `AUTO_INCREMENT` |
| JSON access | `JSON_EXTRACT(doc, '$.key')` |
| Upsert | `ON DUPLICATE KEY UPDATE col = VALUES(col)` — **column-scoped** |
| Stored procedures | **syntax error** — not supported |

Full matrix: `experiments/08_standouts/exp8_compatibility.md`.

## Not redone at RF=3

Neither half depends on replication factor: dialect support is a parser
question, and the HTAP isolation test measures CPU contention between two
workloads on one machine. Checked before deciding, not assumed.
