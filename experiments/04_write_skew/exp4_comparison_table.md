# Experiment 4 — The Write-Skew Test: Comparison

Five conditions, same interleaving (two sessions each read
`count(*) FROM doctors WHERE on_call = true` → 2, then each independently
takes a *different* doctor off-call, then both commit), varying only the
engine and/or the isolation level. This is a controlled experiment on one
variable — isolation level — not a three-way vendor comparison; C3/C4 on
the same engine (CockroachDB) is the part that actually isolates it.

## The results table

| # | Condition | Isolation level | Concurrency control | Failed at step | Anomaly? |
|---|---|---|---|---|---|
| C1 | TiDB, default | Repeatable Read (Snapshot Isolation) | Pessimistic locking (per-row) | none — both commit | **Yes — write skew** |
| C2 | TiDB, default + `FOR UPDATE` | Repeatable Read (Snapshot Isolation) | Pessimistic locking + explicit row lock on read | none — both commit (naive) | **Yes — write skew, even with `FOR UPDATE`** (see C2b below) |
| C2b | TiDB, default + `FOR UPDATE` + app-level invariant check | Repeatable Read (Snapshot Isolation) | Pessimistic locking + explicit row lock + conditional abort | Session B, application-level `ROLLBACK` before its write | No — invariant preserved |
| C3 | CockroachDB, default | Serializable | Optimistic — write intents, validated at commit | Session A's `COMMIT` (SQLSTATE 40001) | No — one txn rejected |
| C4 | CockroachDB, forced Read Committed | Read Committed | Optimistic — write intents, no serializable validation | none — both commit | **Yes — write skew, same engine as C3** |
| C5 | Spanner Omni, read-write txn | not lowerable | Optimistic (2PC + commit-wait), validated at commit | Session B's `COMMIT` (`Aborted`) | No — one txn rejected |

## Headline finding: it's the isolation level, not the vendor

C3 vs. C4 is the finding that actually matters for the paper: **the same
engine, same schema, same interleaving**, produces write skew or doesn't,
purely as a function of which isolation level the client requests.
CockroachDB is not "safer" than TiDB in any vendor sense — at Read
Committed it is exactly as vulnerable to this anomaly as TiDB is at its
default. The anomaly tracks the isolation level's guarantees
(specifically: serializable validation catches read-then-disjoint-write
conflicts across rows; snapshot isolation and read committed do not),
not which company built the database.

## Secondary finding (C2/C2b): explicit locking is necessary but not sufficient

C2 produced a genuinely more interesting result than the runbook's simple
"blocks → no skew" prediction. `SELECT ... FOR UPDATE` did exactly what it
promises — it serialized the two sessions' reads, forcing Session B to
wait for Session A's commit and then see the *fresh* post-commit value
(`count = 1`, not the stale `2` plain Snapshot Isolation would have shown).
But the naive version of C2 still produced write skew, because nothing in
the transaction *used* that fresh read — the `UPDATE` ran unconditionally
regardless of what the lock revealed.

Only C2b — the same lock, plus an explicit application-level check that
aborts when the invariant would be violated — actually closed the
anomaly. This distinguishes two things that are easy to conflate:
`FOR UPDATE` prevents *stale reads under concurrency*; it does not, by
itself, prevent *write skew*. Preventing write skew under Snapshot
Isolation requires the application to explicitly re-validate its
invariant against the locked, fresh read before deciding to write — the
lock alone only makes that validation possible, it doesn't perform it.

## Where the failure surfaces: block vs. abort

The runbook specifically asks *where* the losing transaction is rejected,
because the step number distinguishes pessimistic from optimistic
concurrency control:

- **TiDB (pessimistic, C1/C2/C2b)**: when there *is* contention on the same
  row (C2's `FOR UPDATE`, or Experiment 3's same-row demo), the second
  session **blocks at the write/read-lock step**, before it ever gets to
  commit. When rows differ (C1, C2 naive), there is no contention to block
  on at all — both proceed and commit freely.
- **CockroachDB and Spanner (optimistic, C3/C5)**: both sessions' writes
  succeed immediately regardless of row overlap; the conflict is only
  detected when the losing transaction tries to **commit**, and is
  rejected there (`SQLSTATE 40001` / `Aborted`). Neither CockroachDB nor
  Spanner ever blocks a statement mid-transaction to prevent this anomaly
  — they let both transactions run to the write, then reject one at commit.

## Artifacts

- `experiments/04_write_skew/exp4_c1.txt` — TiDB default (write skew)
- `experiments/04_write_skew/exp4_c2.txt` — TiDB + `FOR UPDATE`, naive (still write skew) and C2b, corrected (no skew)
- `experiments/04_write_skew/exp4_c3.txt` — CockroachDB Serializable (40001, no skew)
- `experiments/04_write_skew/exp4_c4.txt` — CockroachDB Read Committed (write skew, same engine as C3)
- `experiments/04_write_skew/exp4_c5.txt` — Spanner Omni read-write transaction (Aborted, no skew)
