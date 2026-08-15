# Experiment 9 — Results — CockroachDB

## Headline: zero failures

| Metric | Value |
|---|---|
| Total transactions | **55,356** |
| Failed transactions | **0** |
| Median latency, whole run | flat, ~4.7–5.9 ms |
| p99 pre-kill baseline | ~7 ms |
| p99 after the kill | degrades **almost immediately**, 10–24 ms, volatile |
| p99 recovered by T+300 s? | **no** — still oscillating 10–20 ms |
| Balance invariant | held |

Raw data: `experiments/09_fault_tolerance/exp9_crdb_faulttolerance.csv`.
Full write-up: `experiments/09_fault_tolerance/exp9_crdb_results.md`.
Chart: `results/benchmark_charts/exp9_crdb_timeline.png`.

Killing 1 of 3 replicas leaves a 2-of-3 Raft quorum, so writes continue
uninterrupted. The invariant holds by construction: every transfer is a
zero-sum $1 move between the same two accounts, and 55,356 is even, so a
fully-successful run cannot change the net balance.

## The finding a success/failure count would have missed

Median latency was **completely unaffected** by either the kill or the
restart. Tail latency was not. Starting almost immediately after T+60 s, p99
became volatile and elevated — spiking as high as 24 ms — and **never
settled back to baseline for the rest of the run**, still oscillating in the
10–20 ms range at T+290 s, thirty seconds after the nominal recovery window
had closed.

The most plausible explanation is ongoing background range rebalancing:
replicas shed from the dying node during the outage, then rebalanced back
onto it after restart, competing for resources well past the outage itself.
Plausible, not confirmed.

## Recovery evidence

- `cockroachdb-26 node status`: all 3 nodes back to `is_live: true`; node 2's
  `started_at` matches the restart timestamp — direct evidence it really
  went down and came back.
- During the outage the console showed **57 of 76 ranges under-replicated
  but 0 unavailable** (`results/screenshots/exp9_crdb_down.png`) — quorum
  held throughout even while replication was degraded.
- After restart, `crdb_internal.ranges` confirmed `under_replicated = 0`.
