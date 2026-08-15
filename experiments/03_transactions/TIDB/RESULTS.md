# Experiment 3 — Results — TiDB

## Latency (pooled across 3 runs × 200 transactions)

| Metric | Value |
|---|---|
| Median | **6.38 ms** |
| p95 | 7.28 ms |
| p99 | 9.84 ms |

Raw per-transaction data: `experiments/03_transactions/exp3_latency.csv`,
rows with `engine=tidb`.

## Lock demo

- `information_schema.cluster_tidb_trx` confirmed the open transaction's
  pessimistic-lock buffer held exactly **2 keys** (`MEM_BUFFER_KEYS = 2`)
  *before* commit — locks are acquired at the `UPDATE`, not deferred to
  commit.
- Forcing a second transaction to touch the same row (`id = 1`) produced a
  **real block**, captured in `information_schema.data_lock_waits`. The
  waiting transaction's id and the holding transaction's id matched the ids
  seen in `cluster_tidb_trx`, and `KEY_INFO` confirmed the contended row.

Raw output: `experiments/03_transactions/exp3_tidb_locks.txt`.

## What it means

TiDB blocks where CockroachDB does not. The difference is mechanical, not a
matter of degree: CockroachDB's write intents let two transactions on
different rows proceed in parallel and settle any conflict at commit; TiDB
takes the lock at the `UPDATE` and makes the second transaction wait.

That eager, blocking model is consistent with TiDB's roughly 70% higher
median latency than CockroachDB in this test — every transaction pays for
lock acquisition up front, and the TSO round trip to the single PD process
(Experiment 5) adds a further fixed cost at every transaction start.

This mechanism reappears in Experiment 4: because the write-skew scenario
touches **different** rows, TiDB has nothing to block on, and the anomaly
goes through.
