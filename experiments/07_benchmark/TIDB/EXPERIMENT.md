# Experiment 7 — Indicative Performance — TiDB

## The benchmark harness

`experiments/07_benchmark/bench.py` is shared by all engines — one code path
each, selected by `--engine`, so the sweep is provably identical across
them. The sweep is **3 workloads × 5 concurrency levels × 3 repetitions ×
30 s**, i.e. 45 measured combinations per engine:

- workloads: `point_read`, `point_write`, `transfer` — all against the
  50,000-row `accounts` table
- concurrency: 1, 4, 16, 32, 64 threads
- one connection per worker thread, warm-up before timing, retries on
  serialization failure logged as **their own metric** rather than hidden
  inside latency

Results append to `experiments/07_benchmark/bench_results.csv` with columns
`engine,workload,concurrency,rep,ops_per_sec,p50,p95,p99`.

**Run one engine at a time with the other two stopped** — logged in
`results/env.txt` for every run.

## R3 — this is not a ranking

Three engines, different internal topologies, one laptop, over loopback,
default settings, one of them a Preview build. What this experiment
legitimately shows is **the shape of each engine's own response to rising
concurrency**. The charts are built as separate panels with separate y-axes
specifically to prevent a head-to-head reading.

## Prerequisites

TiDB playground up and seeded. **CockroachDB and Spanner stopped.**

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run_bench.sh` | `bash run_bench.sh` — the full 45-combination sweep |

## Charts

After all engines have been swept:

```bash
source .venv/bin/activate
python3 experiments/07_benchmark/make_charts.py
```

Produces `results/benchmark_charts/exp7_throughput.png`,
`exp7_latency_p99.png` and `exp7_retry_rate.png` — four panels each
(CockroachDB, TiDB, Spanner RF=1, Spanner RF=3), median across the 3
repetitions as the line and min–max as the shaded band.

## Artifacts of record

- `experiments/07_benchmark/bench_results.csv` (rows with `engine=tidb`)
- `results/benchmark_charts/exp7_*.png`
