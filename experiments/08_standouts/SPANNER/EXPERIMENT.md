# Experiment 8 — Standout Features — Spanner Omni

## What this experiment does

Two parts:

1. **Interleaved-table locality** — Spanner's standout. `order_items` is
   declared `INTERLEAVE IN PARENT orders`, so each order's line items are
   physically stored beside the parent row. The test compares a join on the
   interleaved schema against the identical join on a non-interleaved twin
   table (`order_items_flat`).
2. **SQL compatibility** — Spanner's column of the seven-feature matrix,
   plus a full-text query against the bundled sample database.

## About the compatibility probes

The compatibility matrix was run interactively, statement by statement, with
the results recorded directly into
`experiments/08_standouts/exp8_compatibility.md` — that file is the artifact
of record. The `.sql` file here collects the same probes in runnable form,
using the exact syntax each engine accepted (or rejected), so the matrix can
be reproduced in one pass instead of retyped.

## Prerequisites

`docker start spanneromni`. Runs against the original single-server
container (RF=1), databases `seminar` and `retail-sample`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_compat.sh` | `bash 01_compat.sh` |
| 2 | `02_interleaved_locality.sh` | `bash 02_interleaved_locality.sh` |
| 3 | `03_fulltext.sh` | `bash 03_fulltext.sh` |

Step 2 runs three queries in a fixed order — A, B, then the flat
comparison — because query A produces a result that only makes sense as a
contrast with B. See `RESULTS.md`.

## Not redone at RF=3, and why the locality demo specifically was not

The compatibility matrix has no replication dependency. The interleaving
demo *is* about distribution, so it was considered — and deliberately left
alone. Experiment 1's redo shows the whole dataset still fits in **one
group** even at RF=3, so re-running would almost certainly reproduce
`remote_calls: 0` for an unrelated, already-confirmed reason ("nothing is
split yet") rather than because interleaving preserved co-location under
real distribution. Running it would have produced a misleading confirmation.

## Artifacts of record

- `experiments/08_standouts/exp8_spanner_interleaved_plan.txt`
- `experiments/08_standouts/exp8_spanner_flat_plan.txt`
- `experiments/08_standouts/exp8_spanner_01.txt` … `exp8_spanner_05.txt`
- `experiments/08_standouts/exp8_spanner_fulltext.txt`
- `experiments/08_standouts/exp8_compatibility.md`
- `results/screenshots/exp8_spanner_interleaved_plan.png`
