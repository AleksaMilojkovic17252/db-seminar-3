# Experiment 9 — Results — TiDB

## Headline: zero failures

| Metric | Value |
|---|---|
| Total transactions | **46,812** |
| Failed transactions | **0** |
| Median latency, whole run | flat, ~5.5–7 ms |
| p99 pre-kill baseline | ~8 ms |
| p99 after the kill | stays near baseline until **~T+110 s**, then climbs to 10–28 ms |
| p99 recovered by T+300 s? | **no** — still noisy |
| Balance invariant | held |

Raw data: `experiments/09_fault_tolerance/exp9_tidb_faulttolerance.csv`.
Full write-up: `experiments/09_fault_tolerance/exp9_tidb_results.md`.
Chart: `results/benchmark_charts/exp9_tidb_timeline.png`.

Same reason as CockroachDB: RF=3 across 3 stores means losing one still
leaves a 2-of-3 Raft quorum per region. 46,812 is even and every transfer is
zero-sum, so a fully-successful run mathematically cannot change the net
balance — consistent with the measured sum.

## The interesting difference: TiDB's degradation is *delayed*

CockroachDB's p99 jumps almost immediately after the kill. TiDB's stays
close to its ~8 ms baseline through roughly **T+110 s — a full 50 seconds
after the kill** — before climbing and becoming volatile (10–28 ms, with a
single 206 ms outlier right before the T+180 s restart). Degradation then
continues, noisy, through the rest of the run, never fully settling by
T+300 s.

The most plausible read: CockroachDB's Raft leadership failover for the
affected ranges kicks in quickly once heartbeats are missed, while TiDB's
detection and rebalancing thresholds are more conservative. **Inferred from
the observed timeline, not independently confirmed** against either engine's
failure-detection configuration — flagged as a hypothesis for the paper's
discussion, not a settled fact.

## Recovery evidence

- `information_schema.tikv_store_status`: store 1 returned to `Up` after
  restart.
- Dashboard (`results/screenshots/exp9_tidb_down.png`): Cluster Info →
  Instances shows `127.0.0.1:20160` as `Unreachable` during the outage while
  stores 2, 3 and TiFlash remain `Up` — visual confirmation of a
  single-store failure without cluster-wide disruption.
