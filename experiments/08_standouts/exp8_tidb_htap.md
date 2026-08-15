# Experiment 8 — TiDB HTAP Demo

## Setup

TiFlash replicas enabled on all three joined tables (a genuine MPP join
needs every table replicated, not just one):
```sql
ALTER TABLE orders SET TIFLASH REPLICA 1;
ALTER TABLE order_items SET TIFLASH REPLICA 1;
ALTER TABLE products SET TIFLASH REPLICA 1;
```
All three reached `PROGRESS=1, AVAILABLE=1` within seconds at this
seminar data scale (`information_schema.tiflash_replica`).

## The HTAP query — full MPP execution

```sql
SELECT p.category, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
GROUP BY p.category;
```

`EXPLAIN ANALYZE` (full plan: `exp8_tidb_01.txt`; screenshot:
`results/screenshots/exp8_tidb_htap_plan.png`) shows **every operator**
running in `mpp[tiflash]` — both `HashJoin`s (`order_items`⋈`orders`,
`order_items`⋈`products`), and critically both `HashAgg`s: a local
partial aggregation (`HashAgg_140`, per-partition after a
`ExchangeSender`/`HashPartition` re-shuffle by `category`) followed by a
final global `HashAgg_143` combining the partials. Only the tiny 8-row
final result crosses back to `root` via `TableReader_147`. Total time
32.5ms for a 3-way join + aggregation over 120,000 `order_items` rows.

**This is the same two-phase distributed-aggregation pattern flagged as
Spanner's standout finding in Experiment 2** — Spanner did this on its
normal OLTP-facing path with no special configuration; TiDB only produces
it when TiFlash is enabled and the optimizer chooses the MPP engine.
Experiment 2's plain TiDB plan (no TiFlash) centralized the aggregation at
`root` instead. Worth stating explicitly: HTAP is TiDB's way of buying
that same capability for OLAP-shaped queries, not something its row store
does by default.

## The actual HTAP claim: does OLTP p99 hold up under concurrent OLAP load?

The plan by itself isn't the HTAP result — the isolation between OLTP and
OLAP under concurrent load is (per the runbook). Method: run
`point_read`/`point_write` (Experiment 7's benchmark, 16 threads, 20s) with
and without the HTAP query looping concurrently
(`experiments/08_standouts/htap_load.py`) in a second process. Both runs →
`experiments/08_standouts/exp8_tidb_htap_oltp.csv`.

| Workload | metric | no HTAP load | with concurrent HTAP load | change |
|---|---|---|---|---|
| `point_read` | ops/sec | 9432.10 | 7024.85 | **-25%** |
| `point_read` | p99 | 4.245 ms | 5.957 ms | **+40%** |
| `point_write` | ops/sec | 2539.95 | 2460.65 | -3% (noise) |
| `point_write` | p99 | 11.630 ms | 11.994 ms | +3% (noise) |

## Interpretation

Not the clean "OLTP is untouched" story the runbook anticipated — and
that's worth reporting honestly rather than rounding it off. `point_write`
latency is essentially unaffected (within run-to-run noise), which is
consistent with HTAP's design: writes go to TiKV's row store and the
concurrent query reads from TiFlash's separate columnar replica, so the
write path genuinely doesn't contend with the OLAP scan. `point_read`,
however, took a real hit — about 40% higher p99 and 25% lower throughput
with the HTAP query running.

The likely explanation is the deployment, not the isolation design: this
is a single laptop where TiDB, PD, TiKV, and TiFlash all share the same
CPU cores (`tiup playground`), so a CPU-hungry MPP query can still crowd
out OLTP reads at the process-scheduling level even though the *storage
engines* are cleanly separated. Production HTAP deployments typically run
TiFlash on separate nodes from TiKV specifically to avoid this. This
caveat belongs in the paper alongside the result — the finding is "storage
separation holds, but read-path CPU contention does not disappear on a
single shared machine," not an unqualified "TiDB's HTAP isolation failed"
or "held perfectly."

## Artifacts

- `experiments/08_standouts/exp8_tidb_01.txt` — full `EXPLAIN ANALYZE` plan
- `results/screenshots/exp8_tidb_htap_plan.png` — TiDB Dashboard statement detail
- `experiments/08_standouts/htap_load.py` — OLAP load generator used for the isolation test
- `experiments/08_standouts/exp8_tidb_htap_oltp.csv` — before/after OLTP latency data
