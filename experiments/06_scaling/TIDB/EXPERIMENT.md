# Experiment 6 — Scaling & Rebalancing — TiDB

## What this experiment does

Adds a **4th TiKV store to the running playground** and watches peers
redistribute. No restart — `tiup playground scale-out` operates on the live
cluster.

## Prerequisites

TiDB playground up and seeded, running in its own terminal.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_before.sql` | `mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_before.sql` |
| 2 | `02_scale_out.sh` | `bash 02_scale_out.sh` — from a **second** terminal, leaving the playground running in the first |
| 3 | `03_after.sql` | wait for rebalancing, then run as step 1 |

## Note on the method

The runbook's fallback (T-19) was to restart the playground if `scale-out`
was unavailable. It **was** available in this TiUP version — confirmed via
`tiup playground --help` — so the restart fallback was avoided. That matters
for validity: a restart would have destroyed the before/after comparison.

## Artifacts of record

- `experiments/06_scaling/before_after.md`
- `results/screenshots/exp6_tidb_regions.png`

**Tooling limitation, recorded not chased:** the Dashboard's Key Visualizer
did not render a usable heatmap at this scale — it likely needs more write
history than a small seminar dataset accumulates. **Cluster Info →
Instances** was substituted as the artifact; it shows the 4th TiKV instance
`Up` with a visibly later start time than the original three, which is
direct evidence it joined a live cluster rather than the whole playground
having been restarted.
