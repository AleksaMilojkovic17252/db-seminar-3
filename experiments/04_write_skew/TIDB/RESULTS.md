# Experiment 4 — Results — TiDB

| # | Setup | Concurrency control | Failed at step | Anomaly? |
|---|---|---|---|---|
| C1 | Repeatable Read (Snapshot Isolation), default | pessimistic locking, per row | none — both commit | **Yes — write skew** |
| C2 | SI + `SELECT … FOR UPDATE` | pessimistic + explicit row lock on read | none — both commit | **Yes — write skew, even with `FOR UPDATE`** |
| C2b | SI + `FOR UPDATE` + app-level invariant check | pessimistic + lock + conditional abort | Session B, application-level `ROLLBACK` before its write | **No** |

Raw transcripts: `experiments/04_write_skew/exp4_c1.txt`, `exp4_c2.txt`.

## C1 — the baseline anomaly

Both `UPDATE`s succeeded immediately; neither blocked. Both committed. Final
count = **0**.

The reason nothing blocked is the interesting part: ids 1 and 2 are
**different rows**, so TiDB's pessimistic locking — which blocked
immediately on same-row contention in Experiment 3 — has nothing to contend
over here. Each `UPDATE` locks only the row it touches. Snapshot Isolation
validates each transaction against the rows *it wrote*, not against a
logical invariant spanning rows neither transaction wrote to.

## C2 — the finding the runbook got wrong

The runbook predicted `FOR UPDATE` would block or abort and prevent the
skew. Half of that happened: session B **did** block, for a measured
**16.154 seconds**, and when it unblocked its read returned the fresh
post-commit value **1**, not the stale `2` plain Snapshot Isolation would
have shown. The lock did exactly what it promises.

The anomaly still occurred, because nothing in B's transaction *used* that
information. The `UPDATE` ran unconditionally regardless of what the lock
revealed. Final count = 0.

## C2b — what actually closes it

Same lock, plus one conditional: B checks the count it just read, sees that
taking another doctor off call would leave zero, and rolls back. Final count
= 1.

## The distinction this draws

`SELECT ... FOR UPDATE` prevents **stale reads under concurrency**. It does
not, by itself, prevent **write skew**. It only supplies the application
with the information needed to prevent the anomaly — actually preventing it
requires the application to branch on that information.

This mirrors a real-world footgun closely: teams add `FOR UPDATE`, assume
they are now safe from write skew, and never add the corresponding invariant
check. C2 is the failure mode; C2b is the fix.
