# Experiment 4 — Results — Spanner Omni

| # | Isolation level | Concurrency control | Failed at step | Anomaly? |
|---|---|---|---|---|
| C5 | not lowerable — read-write transactions only | optimistic (2PC + commit-wait), validated at commit | **Session B's `COMMIT`** (step 8) | **No** — one txn rejected |

Raw transcript: `experiments/04_write_skew/exp4_c5.txt`.

Deployment: original single-server container (RF=1), database `seminar`.
Not redone at RF=3 — isolation-level behaviour does not depend on
replication factor.

## What happened

Both sessions' `UPDATE`s succeeded immediately. Neither blocked — the same
optimistic signature CockroachDB showed in C3, and the opposite of TiDB's
pessimistic block in Experiment 3. The conflict surfaced only at commit
time, where session B was rejected with `Aborted`. Final count = 1;
invariant held.

## What it adds to the comparison

Spanner offers **no lower isolation tier** for read-write transactions.
Where TiDB ships Snapshot Isolation by default and CockroachDB lets a client
ask for Read Committed (C4), Spanner does not expose the choice at all.

That is a design position, not a missing feature, and it is worth a sentence
in the paper: the three engines differ less in what they *can* guarantee
than in which guarantee each considers safe to make the default — and
Spanner is the one that removes the decision from the application developer
entirely.
