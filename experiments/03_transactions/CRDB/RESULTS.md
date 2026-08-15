# Experiment 3 — Results — CockroachDB

## Latency (pooled across 3 runs × 200 transactions)

| Metric | Value |
|---|---|
| Median | **3.78 ms** |
| p95 | 5.00 ms |
| p99 | 5.88 ms |

Raw per-transaction data: `experiments/03_transactions/exp3_latency.csv`,
rows with `engine=crdb`.

## Lock demo

`crdb_internal.cluster_locks` showed **two `Exclusive`, `Unreplicated`
write intents** held by the open transaction on rows 1 and 2 of `accounts`,
both tagged `isolation_level: SERIALIZABLE`.

The important part is what *didn't* happen: nothing in this experiment
forced a second transaction to wait. Write intents are local bookkeeping,
not a blocking lock — they only matter when another transaction actually
collides with the same key, and the collision is resolved at commit time.

Raw output: `experiments/03_transactions/exp3_crdb_locks.txt`.

## What it means

The lock demo is the mechanism behind the latency number. CockroachDB pays
no pessimistic-handshake cost and no centralised-timestamp round trip
(contrast TiDB's PD TSO in Experiment 5): a transaction writes its intents
locally and resolves them at commit. That is consistent with it having the
lowest median of the three in this test.

**This is not a ranking (R3).** Three engines, different internal
topologies, one laptop, default settings. What the number supports is the
narrower claim that CockroachDB's optimistic model has a cheaper typical
path here — and the lock demo shows *why*, which a latency figure alone
would not.
