# Experiment 7 — Indicative Performance — CockroachDB

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

3-node cluster up and seeded. **TiDB and Spanner stopped.**

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run_bench.sh` | `bash run_bench.sh` — the full 45-combination sweep, ~25 min |

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

## Data-hygiene note worth repeating

A smoke test (`--duration 3 --reps 1`) left rows in `bench_results.csv` with
colliding `rep=1` labels against the real 30 s sweep at concurrency 1 and 4.
They were identified by exact value match and removed before analysis, so
the chart and median aggregation were not polluted by short-duration noise.
If you re-run a smoke test, clean up after it.

## Artifacts of record

- `experiments/07_benchmark/bench_results.csv` (rows with `engine=crdb`)
- `results/benchmark_charts/exp7_*.png`
