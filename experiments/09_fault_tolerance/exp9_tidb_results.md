# Experiment 9 — Fault Tolerance: TiDB

**Method:** identical protocol to the CockroachDB run — continuous
single-threaded transfer loop (alternating debit/credit between accounts
1 and 2), 300s total. TiKV store 1 (`127.0.0.1:20160`) killed with
`kill -9` at T+60s, restarted at T+180s, run continued to T+300s. RF=3
across the 3 original TiKV stores throughout (store `3001`, the ephemeral
scale-out addition from Experiment 6, was already down on its own before
this test started — unrelated).

## Headline result: zero transaction failures, same as CockroachDB

**All 46,812 transactions across the full 300s run succeeded — zero
failures**, including while the killed store was down. Same underlying
reason as CockroachDB: RF=3 across 3 stores means a single store loss
still leaves a 2-of-3 Raft quorum per region, so writes continue.
Invariant check: 46,812 is even, and every transfer is a zero-sum $1 move
between the same two accounts, so a fully-successful run mathematically
cannot change the net balance — consistent with the measured sum
(75308.88) versus this session's earlier readings.

## Latency shape: different from CockroachDB in an interesting way

See `results/benchmark_charts/exp9_tidb_timeline.png`. Median (p50)
latency is flat throughout (~5.5-7ms) exactly like CockroachDB — the
typical request path is untouched by the outage.

**But the tail-latency degradation builds up on a different timeline
than CockroachDB's.** CockroachDB's p99 jumped almost immediately after
its T+60s kill. TiDB's p99 stays close to its ~8ms baseline through
roughly T+110s — a good 50 seconds after the kill — before climbing and
becoming volatile (10-28ms, with a single 206ms outlier transaction right
before the T+180s restart). Degradation then continues, noisy, through
the rest of the run, never fully settling by T+300s, same long-tail
pattern as CockroachDB showed.

The most plausible read: CockroachDB's Raft leadership failover for the
affected ranges kicks in quickly once heartbeats are missed, while TiDB's
detection/rebalancing of the dead store appears to take longer to
meaningfully affect client-visible latency — plausibly due to different
default heartbeat/election-timeout tuning between the two systems, or PD's
own store-liveness detection cadence. This is inferred from the observed
timeline, not independently verified against either system's internal
timeout configuration — worth flagging as a hypothesis for the paper
rather than a confirmed mechanism.

## Recovery evidence

- **Store status**: `information_schema.tikv_store_status` confirmed
  store 1 returned to `Up` after restart.
- **TiDB Dashboard** (`results/screenshots/exp9_tidb_down.png`): Cluster
  Info → Instances shows `127.0.0.1:20160` as `Unreachable` during the
  outage window, while stores 2, 3, and TiFlash remain `Up` — direct
  visual confirmation of the single-store failure without cluster-wide
  impact.

## Cross-engine comparison (not a ranking — R3)

Both engines: zero transaction failures, flat median latency, and a real
tail-latency cost that outlasts the nominal recovery window. The
difference worth keeping for the paper is *when* the tail latency
degrades relative to the kill — immediately for CockroachDB, delayed by
roughly a minute for TiDB — which says something about each engine's
failure-detection timeline, not about which one is "more resilient."
Neither system lost a single transaction; the real cost of a single-node
failure at RF=3 on both engines is entirely a latency-tail story, not an
availability story.

## Artifacts

- `experiments/09_fault_tolerance/exp9_tidb_faulttolerance.csv` — all 46,812 logged transactions
- `results/benchmark_charts/exp9_tidb_timeline.png` — p50/p99 latency + error count over time, kill/restart marked
- `results/screenshots/exp9_tidb_down.png` — TiDB Dashboard showing store 1 unreachable
