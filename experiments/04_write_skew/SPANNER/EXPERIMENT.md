# Experiment 4 — Write Skew — Spanner Omni

Spanner contributes condition **C5**: a read-write transaction at the only
isolation level it offers. There is no lower tier to fall back to — that
non-configurability is itself a design position worth a sentence in the
paper.

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

## Prerequisites

`docker start spanneromni`. This condition ran on the **original
single-server (RF=1)** container, database `seminar`.

**Why it was not redone at RF=3:** write-skew behaviour is a property of
the isolation level, which does not depend on replication factor. This was
checked by inspection before deciding, not assumed. Experiments 1, 2, 3, 6,
7 and 9 *were* redone; 4, 5 and 8 were not, for this reason.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `C5_readwrite_txn.sql` | **two interactive shells** — see the header comment |

## The tooling problem, and how it was solved

`spanner databases execute-sql` is **single-statement per invocation with no
session state**, so it physically cannot hold a transaction open across
separate commands — which this experiment requires.

The fix is the interactive shell:

```bash
docker exec -it spanneromni /google/spanner/bin/spanner sql --database=seminar
```

`\h` inside it confirms there are no explicit transaction meta-commands, but
plain `BEGIN;` / `COMMIT;` SQL statements work directly — the prompt changes
to `spanner-cli(rw txn)>` once a read-write transaction is open, which is
how you know you are actually in one.

The reset statements can still be run through `execute-sql`, one statement
per invocation.

## Artifacts of record

- `experiments/04_write_skew/exp4_c5.txt`
