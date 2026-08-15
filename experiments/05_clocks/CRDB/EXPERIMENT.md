# Experiment 5 — Clocks & Timestamp Ordering — CockroachDB

## What this experiment does

Makes CockroachDB's time model concrete: a **Hybrid Logical Clock (HLC)**,
computed locally on each node and adjusted by timestamps observed from
peers. No central timestamp authority, and no specialised clock hardware.

Two observations:

1. Three successive `cluster_logical_timestamp()` calls, from three separate
   client connections, to show the clock advancing monotonically.
2. The DB Console's **Clock Offset** graph, to show how far the three nodes'
   clocks actually drift from one another in practice.

## Prerequisites

3-node cluster up. See `docs/daily_startup.md`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_hlc.sh` | `bash 01_hlc.sh` |
| 2 | — | DB Console → Metrics → Dashboard: Runtime → **Clock Offset**, screenshot to `results/screenshots/exp5_crdb_clockoffset.png` |

## Gotcha that cost time

The runbook says `crdb_internal.cluster_logical_timestamp()`. That function
**does not exist** in v26.2.0 — it fails with SQLSTATE 42883, unknown
function. The correct call is the plain top-level builtin
`cluster_logical_timestamp()`, with no `crdb_internal.` prefix.

## Artifacts of record

- `experiments/05_clocks/exp5_crdb_timestamps.txt`
- `results/screenshots/exp5_crdb_clockoffset.png`

Not run at RF=3, and not affected by it: the clock mechanism is independent
of replication factor.
