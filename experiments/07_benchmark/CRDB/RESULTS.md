# Experiment 7 — Results — CockroachDB

## Shape of the response to concurrency

- `point_read` throughput **climbs smoothly all the way to 64 threads** — no
  inflection, no collapse.
- **Zero retries across all 45 concurrency × workload × rep combinations.**

Raw data: `experiments/07_benchmark/bench_results.csv`, rows with
`engine=crdb`. Charts: `results/benchmark_charts/exp7_throughput.png`,
`exp7_latency_p99.png`, `exp7_retry_rate.png` (leftmost panel in each).

## The zero-retry result is the interesting one

The runbook predicted the opposite: that CockroachDB at Serializable would
abort and retry under contention where TiDB at Snapshot Isolation would not,
and that the retry-rate chart would show it.

It didn't happen, and the reason is instructive. The benchmark picks
accounts at random from 50,000 rows, so two concurrent transactions almost
never touch the same row. **Serializable isolation only costs you retries
when there is contention to detect** — with none, it is free. TiDB likewise
recorded zero.

That is what makes the retry chart worth showing rather than the throughput
chart: it connects Experiment 7 straight back to Experiment 4. Serializable
validation converts contention into **retries**; snapshot isolation converts
the same contention into **anomalies** instead. Neither cost shows up when
the workload does not contend.

## R3

These figures describe CockroachDB's own scaling shape on this machine. They
are not a comparison against TiDB or Spanner, and the charts are
deliberately built to make that reading difficult.
