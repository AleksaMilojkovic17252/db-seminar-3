# Experiment 3 — Transactions & Commit Protocol — TiDB

## What this experiment does

Two parts:

1. **Qualitative** — a two-terminal demo showing that TiDB acquires
   pessimistic locks at the `UPDATE`, and that a second transaction touching
   the same row **blocks immediately**.
2. **Quantitative** — commit latency for the identical 2-row transfer.

TiDB is pessimistic by default: Percolator-style 2PC with locks taken
eagerly.

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

TiDB playground up and seeded. Other two engines stopped for the benchmark.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_lock_demo.sql` | **three terminals** — see the header comment inside the file |
| 2 | `run_bench.sh` | `bash run_bench.sh` |

## Gotcha that cost time

`information_schema.cluster_tidb_trx.STATE` reads **`Idle`** for a
transaction that is open but sitting between statements — `Running` only
applies while a statement is actively executing. Filtering
`WHERE state = 'Running'` on an idle-but-open transaction returns nothing at
all. The real signal for "this transaction is open and holding locks" is
**`MEM_BUFFER_KEYS`**, not `STATE`.

## Artifacts of record

- `experiments/03_transactions/exp3_tidb_locks.txt`
- `experiments/03_transactions/exp3_latency.csv` (rows with `engine=tidb`)
