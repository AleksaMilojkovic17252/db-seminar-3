# Experiment 9 — Fault Tolerance — Spanner Omni

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

## The one deviation, and why it is not a shortcut

Spanner Omni's root servers are **Kubernetes StatefulSet pods with automatic
self-healing**. There is no "restart the node" step to trigger manually — a
killed pod comes back on its own, on Kubernetes' schedule, not the runbook's.

So this run kills the leader at T+60 s and **observes** recovery timing
rather than **triggering** it at T+180 s. The 300 s window and everything
else are unchanged. This is a genuine architectural difference in *how*
recovery happens, and forcing the other two engines' manual protocol onto it
would have measured Kubernetes rather than Spanner.

## Prerequisites

- `bash setup/start_spanner_multiserver.sh`; `spanner-a-0/1/2` all Running.
- **Run Experiment 6's `05_cleanup.sh` first** if the 4th server from that
  experiment is still registered. A stale registration produced two
  unexplained 1–2 s latency blips in the first attempt at this run.
- CockroachDB and TiDB stopped.

Originally **excluded entirely** — at RF=1 there is no second replica to
kill. Redone 2026-07-29 at real RF=3.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `run.sh` | `bash run.sh` — starts the 300 s loop |
| 2 | `kill_leader.sh` | **second terminal**, at T+60 s |
| 3 | — | charts: `python3 experiments/09_fault_tolerance/make_charts.py --engine spanner` |

Kill the **leader** (`spanner-a-1`, per Experiment 1's descriptor check), not
an arbitrary pod. Killing a follower would test far less.

## Artifacts of record

- `experiments/09_fault_tolerance/exp9_spanner_faulttolerance.csv`
- `experiments/09_fault_tolerance/exp9_spanner_results.md`
- `results/benchmark_charts/exp9_spanner_timeline.png`

No screenshot — the console was not enabled on this deployment at test time,
so the CSV and chart are the artifacts of record.
