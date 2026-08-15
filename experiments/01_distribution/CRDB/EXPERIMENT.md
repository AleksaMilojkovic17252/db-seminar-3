# Experiment 1 — Data Distribution — CockroachDB

## What this experiment does

Records CockroachDB's unit of sharding (**range**), how many ranges the
`orders` table occupies, the replication factor actually in effect, and
where the replicas physically sit. Distribution here is observed through
**replica placement across localities**, not through range count — see
`RESULTS.md` for why.

The cluster runs 3 nodes started with distinct localities
(`region=eu-west,zone=a` / `region=us-east,zone=b` / `region=us-west,zone=c`),
a deliberate deviation from the runbook so that replica placement is driven
by real locality tiers instead of being arbitrary (`results/env.txt`).

## Prerequisites

CockroachDB 3-node cluster up and seeded (`bash setup/start_crdb.sh`, then
the Phase 2 schema/seed load). See `docs/daily_startup.md`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_ranges.sql` | `cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_ranges.sql` |

One file, one session — the `SET allow_unsafe_internals = true;` at the top
is **session-scoped**, so the `crdb_internal.ranges` query must run in the
same session as the `SET`. Splitting them into two invocations fails.

## Gotcha that cost time

`crdb_internal` and `system` access is gated behind
`SET allow_unsafe_internals = true;` from CockroachDB v25.4+. It defaults to
off for **every** user including `root`, and overriding it is written to the
`SENSITIVE_ACCESS` audit channel. Without it:
`ERROR: Access to crdb_internal and system is restricted`.

## Artifacts of record

- `experiments/01_distribution/exp1_crdb_ranges.txt`
- `experiments/01_distribution/exp1_crdb_ranges_orders.txt`
- `results/screenshots/exp1_crdb_ranges.png`
