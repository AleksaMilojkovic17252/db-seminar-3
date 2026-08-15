# Experiment 5 — Clocks & Timestamp Ordering — TiDB

## What this experiment does

Makes TiDB's time model concrete: a **centralised Timestamp Oracle (TSO)**
living in the single PD process. Every transaction start is a round trip to
that one process.

Three successive reads of `@@tidb_current_ts`, each in its own transaction,
to show monotonically increasing timestamps all issued by the same
authority.

## Prerequisites

TiDB playground up. See `docs/daily_startup.md`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_tso.sh` | `bash 01_tso.sh` |

## Gotcha that cost time

`@@tidb_current_ts` reads **0** outside an open transaction. It must be
wrapped in `BEGIN; ... COMMIT;` — this is the runbook's own troubleshooting
item T-18, and it is easy to conclude the variable is broken rather than
that no transaction is open.

## Artifacts of record

- `experiments/05_clocks/exp5_tidb_timestamps.txt`

Not run at RF=3, and not affected by it: the clock mechanism is independent
of replication factor.
