# Experiment 4 — Write Skew — TiDB

TiDB carries the **secondary finding**: that `SELECT ... FOR UPDATE` alone
does not prevent write skew.

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

| # | Setup | File |
|---|---|---|
| C1 | default (Repeatable Read = Snapshot Isolation) | `C1_default.sql` |
| C2 | default + `SELECT ... FOR UPDATE`, unconditional write | `C2_for_update.sql` |
| C2b | C2 **plus** an explicit application-level invariant check | `C2b_for_update_with_check.sql` |

## Prerequisites

TiDB playground up and seeded. Two sessions:

```bash
mysql -h 127.0.0.1 -P 4000 -u root -D seminar
```

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `C1_default.sql` | two terminals, stepping through |
| 2 | `C2_for_update.sql` | reset, then two terminals |
| 3 | `C2b_for_update_with_check.sql` | reset, then two terminals |

Run them in this order. C2b is only meaningful as the correction to C2, and
C2 is only interesting because C1 established the baseline anomaly.

## Verify the isolation level actually in effect

```sql
SELECT @@transaction_isolation;   -- expect REPEATABLE-READ
```

## Artifacts of record

- `experiments/04_write_skew/exp4_c1.txt`
- `experiments/04_write_skew/exp4_c2.txt` (contains both C2 and C2b)
