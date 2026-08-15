# Experiment 5 — Results — TiDB

## Measured

Three calls, three separate transactions:

```
467993659939225602
467993660437561345
467993660765241346
```

Monotonically increasing. Every one of these values was issued by the
**single PD process** acting as the cluster's Timestamp Oracle.

Raw output: `experiments/05_clocks/exp5_tidb_timestamps.txt`.

## What it means

| Property | TiDB |
|---|---|
| Mechanism | centralised Timestamp Oracle (TSO) in PD |
| Centralisation | **full** — every transaction start is a round trip to one process |
| Hardware requirement | none |
| Cost paid | a network round trip per transaction start, and one process on the critical path of every transaction |

This is the design CockroachDB's HLC specifically avoids. It buys a simpler
correctness argument — there is exactly one authority, so ordering is
trivially total — at the cost of putting a single process in the path of
every transaction in the cluster.

It also connects directly to Experiment 3: TiDB's median commit latency
(6.38 ms) sits above CockroachDB's (3.78 ms), and paying a TSO round trip at
every transaction start is a plausible contributor alongside its eager
pessimistic locking. Plausible, not proven — this experiment measures the
mechanism, not its cost attribution.
