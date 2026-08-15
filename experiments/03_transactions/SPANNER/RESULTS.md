# Experiment 3 — Results — Spanner Omni

## Latency (pooled across 3 runs × 200 transactions)

| Metric | RF=1 (original) | RF=3 (redo, 2026-07-29) | Change |
|---|---|---|---|
| Median | **9.95 ms** | **10.14 ms** | +2% — within noise |
| p95 | 12.78 ms | 15.29 ms | +20% |
| p99 | 14.49 ms | 16.74 ms | +16% |

Raw per-transaction data: `experiments/03_transactions/exp3_latency.csv`,
rows with `engine=spanner` and `engine=spanner_multi`.

**R2:** these numbers describe Omni's software-defined TrueTime, not
production Spanner's.

## What the redo settled

The original write-up had to argue from absence. Its reasoning: *if*
Spanner's high latency were caused by cross-replica consensus, then a
single-server RF=1 deployment should have been **faster** than
CockroachDB/TiDB, not slower — and since it wasn't, the overhead must be
dominated by something else (gRPC call overhead, software commit-wait),
not replication cost. Correct reasoning, but untestable without a second
Spanner topology.

Re-running the same benchmark at real RF=3 tests it directly:

- **The median barely moved** (9.95 → 10.14 ms). Whatever dominates
  Spanner's ~2.6x median gap over CockroachDB was already fully present at
  RF=1, so it is not replication cost.
- **The tail moved measurably** (p99 14.49 → 16.74 ms, p95 12.78 → 15.29 ms).
  Real cross-server Paxos consensus is not free — it just concentrates in
  the tail rather than the typical case.

This refines rather than overturns the original hypothesis, and it is now a
measured result instead of an inference from an asymmetry.

## No lock observation

No SQL-exposed lock table was found in this Preview build, so Spanner's
concurrency-control mechanism cannot be inspected the way CockroachDB's
`crdb_internal.cluster_locks` and TiDB's `data_lock_waits` can. Recorded as
an observability gap. What Spanner's behaviour *is* can still be inferred
from Experiment 4's C5: both transactions' writes succeed immediately and
one is rejected at commit — the optimistic pattern, matching CockroachDB
rather than TiDB.
