# Experiment 3 — Transactions & Commit Protocol — CockroachDB

## What this experiment does

Two parts:

1. **Qualitative** — a two-terminal lock-observation demo showing *when*
   CockroachDB takes a write intent and what a second transaction
   experiences.
2. **Quantitative** — commit latency for an identical 2-row transfer.

CockroachDB is optimistic: it writes intents at the `UPDATE` and validates
at commit.

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

3-node cluster up and seeded. Other two engines stopped for the benchmark.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_lock_demo.sql` | **two terminals** — see the header comment inside the file |
| 2 | `run_bench.sh` | `bash run_bench.sh` |

Do the lock demo first: it is the explanation for the latency numbers the
benchmark then produces.

## Gotcha

`crdb_internal.cluster_locks` needs `SET allow_unsafe_internals = true;` in
the **same session** (v25.4+ gate, audit-logged).

## Artifacts of record

- `experiments/03_transactions/exp3_crdb_locks.txt`
- `experiments/03_transactions/exp3_latency.csv` (rows with `engine=crdb`)
