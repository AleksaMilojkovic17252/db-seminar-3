# Experiment 4 — Write Skew — CockroachDB

This engine carries **the controlled comparison** the whole experiment turns
on: conditions C3 and C4 are the same engine, same schema, same
interleaving, differing only in isolation level.

## The scenario, identical on all three engines

Invariant: **at least one doctor must be on call.** Starting state: exactly
two are (`doctors` ids 1 and 2). Two sessions run strictly interleaved:

| Step | Session A | Session B |
|---|---|---|
| 1 · 2 | `BEGIN;` | `BEGIN;` |
| 3 · 4 | reads `count(*) WHERE on_call = true` → 2 | reads the same → 2 |
| 5 · 6 | sets doctor **1** off call | sets doctor **2** off call |
| 7 · 8 | `COMMIT;` | `COMMIT;` |

Each transaction is individually correct. They write **different rows**, so
there is no write-write conflict for the engine to detect. If both commit,
zero doctors are on call and nobody ever observed the violation.

**Record where the loser fails, not just that it failed.** Rejection at step
6 means pessimistic locking; rejection at step 8 means optimistic
validation. The step number is itself a result.

## Reset before every condition

```sql
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2
```

## Conditions run here

| # | Isolation level | File |
|---|---|---|
| C3 | Serializable (default) | `C3_serializable.sql` |
| C4 | Read Committed (forced) | `C4_read_committed.sql` |

## Prerequisites

3-node cluster up and seeded. Two `cockroachdb-26 sql` sessions open:

```bash
cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar
```

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `C3_serializable.sql` | **two terminals**, stepping through the file |
| 2 | `C4_read_committed.sql` | reset first, then two terminals again |

Run C3 before C4. C4 only means anything as a contrast with C3.

## Finding worth recording as a non-gotcha

Read Committed needed **no cluster setting** on this build.
`BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;` then
`SHOW transaction_isolation;` returns `read committed` directly — the
runbook's T-14 fallback
(`SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true;`)
was not required on v26.2.0.

## Artifacts of record

- `experiments/04_write_skew/exp4_c3.txt`
- `experiments/04_write_skew/exp4_c4.txt`
- `results/screenshots/exp4_crdb_abort.png` (the SQLSTATE 40001 error)
