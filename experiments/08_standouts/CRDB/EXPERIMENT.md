# Experiment 8 — Standout Features — CockroachDB

## What this experiment does

CockroachDB's standout — surviving node loss — is not tested here. It was
**generalised into Experiment 9**, which runs the same kill-under-load
protocol against all three engines, which is a far stronger comparison than
a single-engine demo would have been.

What remains for CockroachDB in Experiment 8 is its column of the **SQL
compatibility matrix**: seven dialect features probed identically on all
three engines.

## About the compatibility probes

The compatibility matrix was run interactively, statement by statement, with
the results recorded directly into
`experiments/08_standouts/exp8_compatibility.md` — that file is the artifact
of record. The `.sql` file here collects the same probes in runnable form,
using the exact syntax each engine accepted (or rejected), so the matrix can
be reproduced in one pass instead of retyped.

## Prerequisites

3-node cluster up and seeded.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_compat.sql` | `cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_compat.sql` |

The upsert probe is the one to read carefully — see `RESULTS.md`. It writes
to `accounts`, so run it on a database you are willing to mutate.

## Artifacts of record

- `experiments/08_standouts/exp8_compatibility.md`
