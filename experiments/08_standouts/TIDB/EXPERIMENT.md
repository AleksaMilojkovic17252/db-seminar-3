# Experiment 8 — Standout Features — TiDB

## What this experiment does

Two parts:

1. **HTAP** — TiDB's standout. Enable TiFlash columnar replicas, show the
   query plan switch to MPP execution, and then test the claim that actually
   matters: does OLTP latency hold up under concurrent OLAP load?
2. **SQL compatibility** — TiDB's column of the seven-feature matrix.

The plan by itself is not the HTAP result. The **isolation** between the two
workloads is.

## About the compatibility probes

The compatibility matrix was run interactively, statement by statement, with
the results recorded directly into
`experiments/08_standouts/exp8_compatibility.md` — that file is the artifact
of record. The `.sql` file here collects the same probes in runnable form,
using the exact syntax each engine accepted (or rejected), so the matrix can
be reproduced in one pass instead of retyped.

## Prerequisites

TiDB playground up (with TiFlash — `--tiflash 1`, which the standard start
script includes) and seeded.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_compat.sql` | `mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_compat.sql` |
| 2 | `02_htap_setup.sql` | same; then **wait** for `PROGRESS=1, AVAILABLE=1` |
| 3 | `03_htap_query.sql` | same — the MPP plan |
| 4 | `run_htap_isolation.sh` | `bash run_htap_isolation.sh` — the actual HTAP test |

Step 2 must complete before step 3, or the optimizer will not choose MPP.
At this data scale all three replicas became available within seconds.

## Artifacts of record

- `experiments/08_standouts/exp8_tidb_htap.md`
- `experiments/08_standouts/exp8_tidb_01.txt` (full MPP plan)
- `experiments/08_standouts/exp8_tidb_htap_oltp.csv`
- `experiments/08_standouts/exp8_compatibility.md`
- `results/screenshots/exp8_tidb_htap_plan.png`
