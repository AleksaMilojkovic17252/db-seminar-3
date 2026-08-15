# Experiment 3 — Transactions & Commit Protocol — Spanner Omni

## What this experiment does

Commit latency for the identical 2-row transfer, run **twice**:

- `--engine spanner` — the original single-server container (RF=1).
- `--engine spanner_multi` — the 3-root-server k3s deployment (RF=3),
  added 2026-07-29. Deliberately a **separate** engine label so the original
  RF=1 rows in `exp3_latency.csv` stay untouched.

There is **no lock demo** for Spanner. No SQL-exposed lock table was found
in this Preview build — that is recorded as an observability difference, not
a gap to be worked around with a substitute measurement.

## The benchmark harness

`experiments/03_transactions/bench_transactions.py` is shared by all three
engines — one code path per engine, selected by `--engine`, so the
measurement protocol is provably identical across them. It runs **3
independent runs of 200 transactions each**, sleeping 30 s between runs, and
logs every individual latency to `exp3_latency.csv`
(`engine,run,txn_index,latency_ms`). Median/p95/p99 are computed downstream
from that CSV, not inside the script.

Every transaction is the same 2-row transfer: debit one account, credit the
other, direction alternating each transaction so balances stay stable across
repeated runs.

**Run one engine at a time with the other two stopped or idle** — recorded
in `results/env.txt` for each run. This is a measurement-validity
requirement, not a convenience.

## Prerequisites

- RF=1: `docker start spanneromni` (the Python client connects via
  `SPANNER_EMULATOR_HOST=localhost:15000`).
- RF=3: `bash setup/start_spanner_multiserver.sh` (gRPC on `localhost:30010`,
  database `seminar-multiserver`).

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run_bench_rf1.sh` | `bash run_bench_rf1.sh` |
| 2 | `run_bench_rf3.sh` | `bash run_bench_rf3.sh` |

## The discovery that made this measurable

Python's `google-cloud-spanner` client connects to Spanner Omni through the
standard `SPANNER_EMULATOR_HOST` environment variable, even though Omni's
docs only document Java and Go for custom-endpoint connections. This was
tested empirically, not assumed.

It matters: it means Spanner can be measured with a real persistent client
and real multi-statement transactions (`database.run_in_transaction()`)
instead of the CLI's one-statement-per-invocation path, which carries about
99 ms of process overhead per call. Without it, Spanner could not have been
put on equal footing with the other two engines for latency measurement at
all.

## R2 — required caveat

Every Spanner timing number here reflects Omni's **software-defined
TrueTime**, not the GPS/atomic-clock TrueTime of production Spanner. State
this wherever the number appears.

## Artifacts of record

- `experiments/03_transactions/exp3_latency.csv` — rows with
  `engine=spanner` (RF=1) and `engine=spanner_multi` (RF=3)
