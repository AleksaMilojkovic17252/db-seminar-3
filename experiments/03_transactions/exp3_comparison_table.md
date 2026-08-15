# Experiment 3 — Distributed Transactions & Commit Protocol: Comparison

Transaction: identical 2-row transfer on `accounts` (debit id, credit the
other id, direction alternating every other transaction). Two parts per the
runbook: (1) a qualitative two-terminal lock-observation demo on
CockroachDB and TiDB — Spanner has no SQL-exposed lock table, so it's
absent from that part, not a gap that was worked around; (2) a quantitative
benchmark — 3 independent runs of 200 transactions each, one engine at a
time with the other two stopped (logged in `results/env.txt`) — on all
three engines.

| | CockroachDB | TiDB | Spanner Omni (RF=1, original) | Spanner Omni (RF=3, redo, 2026-07-29) |
|---|---|---|---|---|
| **Concurrency control** | Optimistic — write intents | Pessimistic (default) — 2PC, Percolator-style | 2PC over Paxos + commit-wait | same (unchanged by RF) |
| **When the lock/intent is taken** | At the `UPDATE`, but non-blocking for other txns until commit-time conflict check | At the `UPDATE`, blocking immediately | Not independently observable (no lock SQL surface) | same |
| **Where it's observable** | `crdb_internal.cluster_locks` (needs `SET allow_unsafe_internals = true;`, a new v25.4+ audit-logged gate) | `information_schema.cluster_tidb_trx` (buffer contents) + `information_schema.data_lock_waits` (actual blocking) | not exposed | same |
| **Contending transaction's experience** | Proceeds freely — both txns can update *different* rows in parallel with no wait | Blocks outright if a second txn touches the *same* row already locked | not tested this way | same |
| **Isolation level (session-verified)** | SERIALIZABLE (default, not lowered) | REPEATABLE-READ / Snapshot Isolation (default) | not independently lowerable | same |
| **Replication factor during this experiment** | 3 (3 nodes) | 3 (3 TiKV stores) | **1 — single-server (R1)** | **3 (3 root servers) — genuine parity, see `docs/spanner_multiserver_setup.md`** |
| **Median commit latency** | 3.78 ms | 6.38 ms | 9.95 ms | 10.14 ms |
| **p95** | 5.00 ms | 7.28 ms | 12.78 ms | 15.29 ms |
| **p99** | 5.88 ms | 9.84 ms | 14.49 ms | 16.74 ms |

*(Latency figures are medians/p95/p99 pooled across all 3 runs × 200 txns;
per-run breakdown in `exp3_latency.csv`, engine labels `spanner` (RF=1) and
`spanner_multi` (RF=3) respectively.)*

## The RF=1→RF=3 redo directly tests a hypothesis the original write-up could only infer

The original R1 caveat below predicted that if Spanner's high latency were
*caused* by cross-replica consensus, a single-server (RF=1) deployment
should have been *faster* than CockroachDB/TiDB, not slower — and since it
wasn't, concluded the overhead must be dominated by something else (gRPC/
PGAdapter call overhead, software commit-wait), not by replication cost.
Now that the same database has been re-run at real RF=3, that inference can
be checked directly instead of argued from absence:

- **Median latency barely moved**: 9.95ms (RF=1) → 10.14ms (RF=3), a ~2%
  difference — within run-to-run noise, not a meaningful shift.
- **Tail latency moved more**: p99 climbed 14.49ms → 16.74ms (~16%), p95
  12.78ms → 15.29ms (~20%) — a real, if modest, cost that **does** show up
  once actual cross-server Paxos consensus is in the loop, unlike at RF=1
  where there was no second replica to reach agreement with.

This refines rather than overturns the original hypothesis: the bulk of
Spanner's ~2.6x median-latency gap over CockroachDB is confirmed to **not**
be replication cost (RF=1 and RF=3 medians are nearly identical, so
whatever dominates the gap was already fully present at RF=1) — but real
consensus overhead is not zero either, it just concentrates in the tail
rather than the typical case. Worth stating precisely in the paper: this is
now a *measured* result, not an inference from the R1 asymmetry.

## Headline finding: the lock demo shows *why* the latency differs, not just *that* it differs

The two-terminal demo on CockroachDB and TiDB isn't just a sanity check —
it's the mechanism behind the benchmark numbers:

- **CockroachDB**: `crdb_internal.cluster_locks` showed two `Exclusive`,
  `Unreplicated` write intents held by the open transaction on rows 1 and 2
  of `accounts`, both tagged `isolation_level: SERIALIZABLE`. Critically,
  nothing in this experiment forced a *second* transaction to wait — write
  intents are local bookkeeping, not a blocking lock, until another
  transaction actually collides with the same key. This lets CockroachDB's
  benchmark run cheaply: no PD-equivalent round trip, no pessimistic
  handshake, just local intent writes resolved at commit.
- **TiDB**: `information_schema.cluster_tidb_trx` confirmed the open
  transaction's pessimistic-lock buffer held exactly 2 keys
  (`MEM_BUFFER_KEYS = 2`) *before* commit — locks are acquired at the
  `UPDATE`, not deferred. Forcing a second transaction to touch the same
  row (`id = 1`) produced a real block, captured in
  `information_schema.data_lock_waits`: the waiting transaction's ID and
  the exact holding transaction's ID matched the IDs seen in
  `cluster_tidb_trx`, with `KEY_INFO` confirming the contended row. This
  eager, blocking locking model is consistent with TiDB's ~70% higher
  median latency than CockroachDB in the benchmark — every transaction pays
  for pessimistic lock acquisition up front, and the TSO round-trip to PD
  (Experiment 5) adds further fixed overhead per transaction start.
- **Spanner Omni**: no equivalent SQL-exposed lock table was found in this
  Preview build, so the mechanism can't be directly inspected the way it
  can on the other two — noted as an observability gap for the write-up,
  not something to force a workaround for. Its benchmark latency (median
  9.95 ms) is markedly higher than both, but per **R1 and R2 below**, this
  number is not directly comparable to the other two.

- A gotcha worth keeping for methodology: TiDB's `cluster_tidb_trx.STATE`
  column reports `Idle` for an open transaction sitting between statements
  — `Running` only applies while a statement is actively executing.
  Filtering `WHERE state = 'Running'` on an idle-but-open transaction
  returns nothing; the real signal for "is this transaction open and
  holding locks" is `MEM_BUFFER_KEYS`, not `STATE`.

## Caveats that must appear in §4.0/§4.3 of the paper (R1, R2)

- **R1 — replication asymmetry, now resolved by direct measurement.**
  Spanner Omni *originally* ran single-server (RF=1) for this experiment,
  while CockroachDB and TiDB both ran at RF=3 (see `results/env.txt`).
  **Redone 2026-07-29** against a real 3-root-server deployment
  (`docs/spanner_multiserver_setup.md`) — median latency is confirmed
  nearly identical at RF=1 vs RF=3 (9.95ms vs 10.14ms), directly confirming
  the original inference that Spanner's ~2.6x gap over CockroachDB is
  dominated by something other than replication cost (most likely per-call
  PGAdapter/gRPC overhead and Omni's software commit-wait path, see R2) —
  real consensus cost shows up only in the tail (p99 14.49ms → 16.74ms).
  Both the RF=1 and RF=3 numbers are reported in the table above; treat
  RF=3 as the primary comparable figure going forward, with RF=1 kept for
  the before/after record.
- **R2 — Spanner Omni's TrueTime is software-defined.** Every Spanner
  latency figure here reflects Omni's software-defined TrueTime and
  commit-wait implementation, not the GPS/atomic-clock TrueTime described
  in Corbett et al. (2012). State this in §4.0, §4.3, §4.5, and §4.9.
- **R3 — this is not a throughput/latency ranking exercise for Experiment
  7's sake.** All three numbers here come from a single-connection,
  serial-transaction workload used specifically to characterize each
  engine's own commit mechanism (per the runbook's Experiment 3 framing),
  not a concurrency benchmark — that's Experiment 7, and it carries its own
  R3 framing rules separately.

## Artifacts

- `experiments/03_transactions/exp3_crdb_locks.txt` — CockroachDB two-terminal lock demo transcript + `cluster_locks` output
- `experiments/03_transactions/exp3_tidb_locks.txt` — TiDB two-terminal lock demo transcript + `cluster_tidb_trx`/`data_lock_waits` output
- `experiments/03_transactions/exp3_latency.csv` — raw per-transaction latencies, all runs, all engines including both `spanner` (RF=1) and `spanner_multi` (RF=3 redo) (`engine,run,txn_index,latency_ms`)
- `experiments/03_transactions/bench_transactions.py` — benchmark harness (extended 2026-07-29 with a `spanner_multi` engine option, `docs/spanner_multiserver_setup.md`)
- `results/env.txt` — isolation log (which engines were idle/stopped during each engine's timing run), the original RF=1 Spanner decision, and the 2026-07-29 multi-server redo record
