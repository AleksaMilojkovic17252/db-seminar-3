# Experiment 6 — Scaling & Rebalancing — Spanner Omni

## What this experiment does

Adds a server to the running 3-root-server deployment. This produced a
**structurally different outcome** from CockroachDB and TiDB, not a repeat
of their pattern — which is why it is the most interesting third of this
experiment.

**Redone at RF=3 (2026-07-29).** Originally skipped entirely: at RF=1 there
was nothing to scale into, and it was reported as a qualitative limitation
under rule R1.

## Prerequisites

`bash setup/start_spanner_multiserver.sh`; `kubectl get pods -n spanner-ns`
shows `spanner-a-0/1/2` Running.

## Files, in run order

| # | File | What it does |
|---|---|---|
| 1 | `01_before.sh` | snapshot: servers, groups, leader, disk footprint |
| 2 | `02_attempt_4_root.sh` | tries 3 → 4 **root** servers. **This is expected to fail** — that failure is the finding |
| 3 | `03_add_nonroot.sh` | adds a 4th **non-root** server instead. Succeeds |
| 4 | `04_after.sh` | same snapshot as step 1, for the comparison |
| 5 | `05_cleanup.sh` | removes the 4th server and its PVCs, returning to a clean 3-server state |

Run step 5 before Experiment 9. Skipping it leaves a **stale server
registration** in Spanner's internal directory that Helm's scale-down does
not remove — which is exactly what caused two unexplained latency blips in
the first fault-tolerance run.

## Artifacts of record

- `experiments/06_scaling/exp6_spanner_before.txt`
- `experiments/06_scaling/exp6_spanner_after.txt`
- `experiments/06_scaling/before_after.md`

No screenshot: the multi-server deployment's console was not enabled at test
time, so CLI text is the artifact of record — the same pattern used
elsewhere in this project where a UI was unavailable.
