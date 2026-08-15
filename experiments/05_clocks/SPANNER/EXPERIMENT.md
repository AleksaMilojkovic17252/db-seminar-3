# Experiment 5 — Clocks & Timestamp Ordering — Spanner Omni

## What this experiment does

Demonstrates Spanner's commit-timestamp mechanism: write
`PENDING_COMMIT_TIMESTAMP()` into a column declared with
`allow_commit_timestamp=true`, then read the row back and see that Spanner
replaced the placeholder with a real timestamp **it assigned server-side at
commit**, rather than one the client supplied.

`ledger.created_at` is declared with `OPTIONS (allow_commit_timestamp=true)`
in `schema/schema_googlesql.sql` specifically for this experiment.

## R2 — required caveat

Spanner Omni implements a **software-defined TrueTime** rather than the
GPS/atomic-clock TrueTime described in Corbett et al. (2012). The behaviour
observed here illustrates the commit-wait *mechanism* but not the
uncertainty bounds of a production Spanner deployment. This wording is
reproduced verbatim in `experiments/05_clocks/NOTE.md`.

## Prerequisites

`docker start spanneromni`. Run against the original single-server
container, database `seminar`.

Not redone at RF=3: the clock mechanism does not depend on replication
factor. Checked before deciding, not assumed.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_commit_timestamp.sh` | `bash 01_commit_timestamp.sh` |

The insert must run before the read-back — that is the whole point: the
value written is a placeholder, and the value read is what Spanner chose.

## Artifacts of record

- `experiments/05_clocks/exp5_spanner_commit_timestamp.txt`
- `experiments/05_clocks/NOTE.md` — the R2 caveat text, verbatim
