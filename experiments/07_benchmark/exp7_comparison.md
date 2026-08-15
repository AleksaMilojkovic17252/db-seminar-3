# Experiment 7 — Indicative Performance Characteristics: Comparison

> **Read R3 before reading this file.** This is not a head-to-head
> benchmark and the charts are built specifically to prevent that reading:
> side-by-side panels, each engine/deployment on its own y-axis, never one
> shared axis with several lines. What follows characterizes **each
> engine's own response to rising concurrency** — it does not rank
> CockroachDB, TiDB, and Spanner Omni against each other. CockroachDB and
> TiDB ran at RF=3 throughout; Spanner Omni ran at RF=1 originally (R1) and
> has since been **redone at RF=3** (2026-07-29,
> `docs/spanner_multiserver_setup.md`) — both Spanner results are kept
> below, since the RF=1→RF=3 comparison is itself one of this redo's most
> useful findings. All on one laptop over loopback, one engine a Preview/
> beta build.

**Method:** 3 workloads (`point_read`, `point_write`, `transfer`, all
against the 50,000-row `accounts` table) × 5 concurrency levels
(1/4/16/32/64 threads) × 3 repetitions × 30s fixed measurement window per
combination, one connection per worker thread (Spanner uses its client
library's own internal session pool instead — see `bench.py`'s docstring
for why that's the correct deviation, not a shortcut). One engine run at a
time with the other two stopped (`results/env.txt`); the `spanner_multi`
(RF=3) redo ran alone against the k3s deployment with CockroachDB/TiDB
stopped, same isolation discipline as the original three.

## Charts

- `results/benchmark_charts/exp7_throughput.png` — ops/sec vs. concurrency, log-scaled y per panel
- `results/benchmark_charts/exp7_latency_p99.png` — p99 latency vs. concurrency, log-scaled y per panel
- `results/benchmark_charts/exp7_retry_rate.png` — retry count vs. concurrency, linear y per panel (the interesting one)

All three now render **4 panels** (CockroachDB, TiDB, Spanner RF=1, Spanner
RF=3) since the 2026-07-29 redo. Median across 3 reps as the line, min–max
band as the shaded spread.

## The RF=1→RF=3 redo: a real, substantial cost the original R1 caveat could only gesture at

The original write-up (below) attributed Spanner's flat/low throughput and
steep p99 growth to "Omni's single-server (RF=1) deployment and Preview-build
overhead," explicitly flagged as something that **couldn't be tested**
without a second Spanner topology to compare against. That comparison now
exists, and the effect is workload-dependent in a genuinely informative way:

| Workload | RF=1 → RF=3 change |
|---|---|
| `point_read` | **Barely affected.** Throughput within ~15% at every concurrency level (e.g. 1240 → 1016 ops/sec at 16 threads); no clear direction of effect. Reads don't need cross-replica consensus the way writes do. |
| `point_write` | **Real cost, concentrated at higher concurrency.** Throughput roughly **halves** at 16+ threads (450 → 237 ops/sec at 16 threads, 453 → 241 at 32); p99 roughly **doubles** (55ms → 115ms at 16 threads, 99ms → 209ms at 32, 166ms → 400ms at 64). |
| `transfer` | **The largest cost.** Throughput drops to **roughly a third** at higher concurrency (360 → 101 ops/sec at 16 threads, 342 → 82 at 32, 305 → 96 at 64); p99 **explodes 5x** at max concurrency (239ms → 1303ms at 64 threads). |

This is a clean, interpretable result: single-row reads are close to
RF-invariant, but multi-statement writes pay a real and *concurrency-dependent*
consensus cost that a single-server (RF=1) deployment structurally cannot
exhibit, because there's no second replica to reach agreement with. The
`transfer` workload (2 statements, 2 rows) pays this cost worse than
`point_write` (1 statement, 1 row) — consistent with more round-trips
through consensus per transaction compounding under contention.

**One counter-intuitive wrinkle, worth flagging rather than smoothing over:**
total retries were *lower* at RF=3 than RF=1 for both write workloads
(`point_write`: 43 → 25 total across the sweep; `transfer`: 103 → 66),
despite RF=3 clearly being slower and having higher tail latency. The
likely explanation: retries require two transactions to actually collide
on the same randomly-picked account within the same window, and RF=3's
much lower throughput means far fewer total transactions were attempted in
each fixed 30s window — fewer attempts outweighs each individual
transaction's now-longer collision window. A reminder that raw retry
counts need attempt-volume context, not just concurrency, to interpret
correctly — the same caution the original write-up already applied when
explaining why CockroachDB/TiDB saw zero retries at all.

## Headline finding: the retry-rate chart is the real result, not throughput

CockroachDB and TiDB show **exactly zero retries across all 45 combinations
each** (all 5 concurrency levels × 3 workloads × 3 reps). Spanner Omni is
the only engine where retries appear at all, and they climb steeply with
concurrency: `transfer` goes from 0 retries at 1 thread to a median of 18
retries per 30s window at 64 threads; `point_write` similarly climbs to a
median of ~7–8.

This was not the expected shape. Experiment 3's benchmark used a *fixed*
two-account transfer (`id=1`↔`id=2`), which guarantees contention by
construction. Experiment 7 picks accounts **uniformly at random from
50,000**, so two concurrent transactions colliding on the same account is
genuinely rare — rare enough that CockroachDB's optimistic validation and
TiDB's pessimistic locking simply never got exercised by conflict in this
workload, at any concurrency level tested. The corollary: **contention is
not something that emerges naturally from concurrency alone** at this
account-space size — it has to be deliberately engineered (as Experiment 4
did) to observe how an engine's concurrency-control model behaves under
it. A throughput-only read of Experiment 7 would have missed this
entirely.

Spanner's retries climbing while the other two stayed flat is not
necessarily evidence of a "worse" concurrency-control model — it's
consistent with **Spanner's read-write transactions taking longer to
complete** (see the latency numbers below), which widens the window
during which two transactions can collide on the same account, all else
equal. A slower transaction is a larger target for the birthday-paradox
math against 50,000 accounts. This is a plausible mechanism, not proven
here — a follow-up worth flagging in Chapter 5 rather than asserting as
fact.

## Per-engine shape (not a ranking — R3)

- **CockroachDB**: `point_read` throughput scales smoothly and keeps
  climbing all the way to 64 threads (1.5k → 10.6k ops/sec), never
  plateauing in this range. `point_write`/`transfer` scale too, just from
  a lower base (write amplification + the explicit transaction overhead
  for `transfer`). p99 latency grows roughly log-linearly with
  concurrency — the classic queuing-delay shape of a system with more
  headroom.
- **TiDB**: `point_read` throughput actually **declines** past 16 threads
  (7.1k → 6.7k → 6.4k at 16/32/64) while `point_write`/`transfer`
  continue climbing throughout. This is a genuinely different shape from
  CockroachDB's monotonic climb — worth a sentence in the paper as a
  concrete example of "each engine's own curve," which is exactly what
  R3 asks this experiment to produce instead of a ranking.
- **Spanner Omni (RF=1, original)**: throughput is flatter and lower across
  the board (max ~1.3k ops/sec for `point_read` vs. CockroachDB's ~10.6k and
  TiDB's ~7.5k), and p99 latency grows the most steeply with concurrency
  of the three (14ms → 240ms for `transfer`, 1→64 threads). This reflects
  Omni's single-server deployment and Preview-build overhead — a
  single-server system saturating its one process's capacity under load is
  an expected shape.
- **Spanner Omni (RF=3, redo)**: `point_read`'s shape barely changes from
  RF=1 (still flat, ~1.0-1.2k ops/sec) — consistent with reads not needing
  cross-replica consensus. `point_write`/`transfer` both show a **new,
  distinct shape neither RF=1 Spanner nor CockroachDB/TiDB exhibited**:
  throughput doesn't just plateau, it *degrades* past 16 threads
  (`transfer`: 153 → 101 → 82 → 96 ops/sec at 4/16/32/64 threads) while p99
  keeps climbing steeply throughout (up to 1.3s at 64 threads for
  `transfer`) — real consensus contention under concurrent writes, a shape
  that requires genuine replication to produce and so was structurally
  invisible in the RF=1 run. See the RF=1→RF=3 section above for the full
  before/after numbers.

## Artifacts

- `experiments/07_benchmark/bench.py` — benchmark harness (extended 2026-07-29 with a `spanner_multi` engine option, `docs/spanner_multiserver_setup.md`)
- `experiments/07_benchmark/make_charts.py` — chart generation (now renders 4 panels)
- `experiments/07_benchmark/bench_results.csv` — raw results, all 4 engines/deployments (`engine,workload,concurrency,rep,ops_per_sec,p50,p95,p99,retries`)
- `results/benchmark_charts/exp7_throughput.png`
- `results/benchmark_charts/exp7_latency_p99.png`
- `results/benchmark_charts/exp7_retry_rate.png`
- `results/env.txt` — isolation log for all runs, including the 2026-07-29 multi-server redo record
