# Experiment 4 — Results — CockroachDB

| # | Isolation level | Concurrency control | Failed at step | Anomaly? |
|---|---|---|---|---|
| C3 | Serializable (default) | optimistic — write intents validated at commit | **Session A's `COMMIT`** (step 7) | **No** — one txn rejected |
| C4 | Read Committed (forced) | optimistic, no serializable validation | none — both commit | **Yes — write skew** |

Raw transcripts: `experiments/04_write_skew/exp4_c3.txt`, `exp4_c4.txt`.
Screenshot: `results/screenshots/exp4_crdb_abort.png`.

## C3 — the rejection, verbatim

```
ERROR: restart transaction: TransactionRetryWithProtoRefreshError:
  TransactionRetryError: retry txn (RETRY_SERIALIZABLE): "sql txn"
  meta={id=2689c301 key=/Table/118/1/1/0 iso=Serializable pri=0.03807368
  epo=0 ts=1785252813.666563175,2 min=1785252776.225323564,0 seq=2}
  lock=true stat=PENDING rts=1785252776.225323564,0
  gul=1785252776.725323564,0
  obs={n1@1785252776.225323564,0 n3@1785252804.604030330,0}
SQLSTATE: 40001
```

Final state: `id=1: on_call=true` (A's update never committed),
`id=2: on_call=false` (B's committed). Count = 1. Invariant held.

## C4 — same engine, anomaly reproduced

Both transactions committed with no error. Final count = **0**. The
invariant both transactions individually verified is violated, and nothing
in the system observed it happening.

## Why this pair is the centre of the paper

C3 and C4 differ in **one variable**. Same engine, same schema, same data,
same interleaving, same client. Only the isolation level changed, and the
anomaly appeared.

That means the anomaly is a property of the isolation level, not of the
vendor. CockroachDB is not "safer" than TiDB in any vendor sense — at Read
Committed it is exactly as vulnerable as TiDB is at its default. What
actually differs between the three products is **which default each
considers safe to ship**, which is a judgement about their users rather than
a limit of their engineering.

Without C4, this experiment would have compared two engines that differ in a
dozen ways and attributed one difference to one of them.

## Where the failure surfaces

CockroachDB never blocks a statement mid-transaction to prevent this. Both
sessions' writes succeed immediately regardless of row overlap; the conflict
is detected only when the losing transaction tries to **commit**. That is
the optimistic signature, and it is the opposite of TiDB's behaviour in
Experiment 3 — where a same-row conflict blocks at the `UPDATE`.
