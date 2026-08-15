# Experiment 7 — Results — TiDB

## Shape of the response to concurrency

- `point_read` throughput **declines past 16 threads** — the opposite shape
  to CockroachDB's, which kept climbing to 64.
- **Zero retries across all 45 concurrency × workload × rep combinations.**

Raw data: `experiments/07_benchmark/bench_results.csv`, rows with
`engine=tidb`. Charts: second panel in each of
`results/benchmark_charts/exp7_*.png`.

## What the decline does and does not tell you

TiDB's throughput turning over past 16 threads is a real feature of its
curve on this machine, and it is the kind of thing a per-engine shape
analysis is *for*. What it is not is evidence that TiDB scales worse than
CockroachDB: the playground runs a PD, three TiKV stores, a TiFlash node and
a TiDB node on the same laptop CPU that also has to run the benchmark
client. Contention for cores is a plausible contributor that this setup
cannot separate out.

## Zero retries — same as CockroachDB, different reason to care

TiDB defaults to Snapshot Isolation, so the runbook expected *fewer* retries
than CockroachDB, not equal. Both recorded exactly zero, because random
account selection across 50,000 rows produces almost no contention.

The relevant comparison is with **Spanner**, which recorded retries that
climb steadily with concurrency under the identical workload. That
difference is real and is what the retry chart shows.

## R3

These figures describe TiDB's own scaling shape on this machine. They are
not a comparison against the other two engines.
