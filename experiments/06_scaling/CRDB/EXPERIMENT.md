# Experiment 6 — Scaling & Rebalancing — CockroachDB

## What this experiment does

Adds a **4th node to a running 3-node cluster** and watches data
redistribute. Nothing here may involve restarting an existing node — a
restart destroys the before/after comparison.

The measurement is taken twice: lease-holder counts per node before, and
again roughly 60 seconds after the new node joins.

## Prerequisites

3-node cluster up and seeded.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_before.sql` | `cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_before.sql` |
| 2 | `02_add_node4.sh` | `bash 02_add_node4.sh` |
| 3 | `03_after.sql` | wait ~60 s, then run the same way as step 1 |

Order is the experiment. Running `03_after.sql` before the new node has
settled produces a half-rebalanced snapshot that means nothing.

Screenshot the DB Console → Overview after step 3 →
`results/screenshots/exp6_crdb_rebalance.png`. The **Replicas** column there
is important: it shows a second, slower rebalancing signal the lease-holder
numbers alone do not.

## Artifacts of record

- `experiments/06_scaling/before_after.md`
- `results/screenshots/exp6_crdb_rebalance.png`
- `node4/`, `node4.log` at the repo root (node 4's data directory — not part
  of the regular 3-node cluster)
