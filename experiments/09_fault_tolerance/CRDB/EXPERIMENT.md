# Experiment 9 — Fault Tolerance — CockroachDB

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

3-node cluster up and seeded. (A 4th node left over from Experiment 6 is
permanently dead and unrelated to this test.)

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run.sh` | `bash run.sh` — starts the 300 s loop |
| 2 | `kill_and_restart.sh kill` | **second terminal** at T+60 s: `NODE2_PID=<pid> bash kill_and_restart.sh kill` |
| 3 | `kill_and_restart.sh restart` | same terminal at T+180 s: `bash kill_and_restart.sh restart` |
| 4 | — | charts: `python3 experiments/09_fault_tolerance/make_charts.py --engine crdb` |

Read `kill_and_restart.sh` before starting: it needs node 2's PID, which
you should identify **before** T+60 s rather than scrambling for it mid-run:

```bash
ps aux | grep '[c]ockroachdb-26 start' | grep 26258
```

## Artifacts of record

- `experiments/09_fault_tolerance/exp9_crdb_faulttolerance.csv`
- `experiments/09_fault_tolerance/exp9_crdb_results.md`
- `results/benchmark_charts/exp9_crdb_timeline.png`
- `results/screenshots/exp9_crdb_down.png`
