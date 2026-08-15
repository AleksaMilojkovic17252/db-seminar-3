# Experiment 7 — Results — Spanner Omni

## Shape of the response to concurrency

- **RF=1**: flatter and lower throughout than either of the other two
  engines' curves.
- **Retries climb steadily with concurrency** — the only engine of the three
  to record any at all.

## RF=1 → RF=3: a real cost a single-server deployment structurally cannot show

| Workload | RF=1 → RF=3 |
|---|---|
| `point_read` | **barely affected.** Throughput within ~15% at every concurrency level (e.g. 1240 → 1016 ops/sec at 16 threads), no clear direction of effect |
| `point_write` | **real cost, concentrated at higher concurrency.** Throughput roughly **halves** at 16+ threads (450 → 237 ops/sec at 16; 453 → 241 at 32). p99 roughly **doubles**: 55 → 115 ms at 16, 99 → 209 ms at 32, 166 → 400 ms at 64 |
| `transfer` | **the largest cost.** Throughput drops to roughly **a third** (360 → 101 ops/sec at 16; 342 → 82 at 32; 305 → 96 at 64). p99 **explodes 5x** at max concurrency: **239 ms → 1303 ms at 64 threads** |

Raw data: `experiments/07_benchmark/bench_results.csv`, rows with
`engine=spanner` and `engine=spanner_multi`.

## What it means

Single-row reads are close to replication-invariant — they do not need
cross-replica consensus. Multi-statement writes pay a real and
**concurrency-dependent** consensus cost that RF=1 cannot exhibit by
construction, because there is no second replica to reach agreement with.

`transfer` (2 statements, 2 rows) is hit harder than `point_write` (1
statement, 1 row), consistent with more round trips through consensus per
transaction compounding under load.

This shape appears in none of the other three panels — not RF=1 Spanner, not
CockroachDB, not TiDB.

## One counter-intuitive wrinkle, flagged rather than smoothed over

Total retries were **lower** at RF=3 than at RF=1 for both write workloads
(`point_write`: 43 → 25 across the sweep; `transfer`: 103 → 66).

That is not less contention. It is far fewer transactions **attempted** in
the same fixed 30-second window, at the now-higher per-transaction latency.
A retry *count* is not a retry *rate* when the denominator moves, and this
is exactly the kind of number that would mislead if quoted without the
throughput figures beside it.

## R2 / R3

Spanner's timings reflect Omni's software-defined TrueTime, not production
Spanner's. And these figures describe Spanner Omni's own scaling shape on
this machine — not a ranking against the other two engines.
