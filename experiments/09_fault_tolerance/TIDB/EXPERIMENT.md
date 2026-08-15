# Experiment 9 — Fault Tolerance — TiDB

## The protocol, identical on all three engines

`experiments/09_fault_tolerance/faulttolerance.py` runs a continuous,
single-threaded transfer loop (debit account 1, credit account 2,
alternating direction), logging every transaction's outcome, latency and
elapsed time. 300 seconds total:

| Window | State |
|---|---|
| T+0 – T+60 s | baseline, everything healthy |
| T+60 s | **one storage node/server is killed** |
| T+60 – T+180 s | degraded |
| T+180 s | node restarted |
| T+180 – T+300 s | recovery |

On any failure the script closes and reopens its connection before the next
attempt, mirroring how a real client recovers from a dropped node.

**The script does not kill anything itself.** That is a deliberate manual
step the operator performs in a second terminal at the moment the script
announces, so the actual kill and restart commands stay in the operator's
own shell history rather than being run silently.

## Prerequisites

TiDB playground up and seeded, RF=3 across the 3 original TiKV stores.
(Store `3001`, the ephemeral scale-out addition from Experiment 6, was
already down on its own before this test — unrelated.)

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run.sh` | `bash run.sh` — starts the 300 s loop |
| 2 | `kill_and_restart.sh kill` | **second terminal** at T+60 s: `STORE1_PID=<pid> bash kill_and_restart.sh kill` |
| 3 | `kill_and_restart.sh verify` | at T+180 s and after, to confirm the store is back `Up` |
| 4 | — | charts: `python3 experiments/09_fault_tolerance/make_charts.py --engine tidb` |

Find TiKV store 1's PID before starting:

```bash
ps aux | grep '[t]ikv-server' | grep 20160
```

## Artifacts of record

- `experiments/09_fault_tolerance/exp9_tidb_faulttolerance.csv`
- `experiments/09_fault_tolerance/exp9_tidb_results.md`
- `results/benchmark_charts/exp9_tidb_timeline.png`
- `results/screenshots/exp9_tidb_down.png`
