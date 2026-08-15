# Experiment 9 — Fault Tolerance: CockroachDB

**Method:** continuous single-threaded transfer loop (alternating debit/credit
between accounts 1 and 2), 300s total. Node 2 (`region=us-east,zone=b`)
killed with `kill -9` at T+60s, restarted at T+180s, run continued to
T+300s. RF=3 across 3 nodes throughout (a 4th node from Experiment 6
remains permanently dead/unrelated to this test).

## Headline result: zero transaction failures

**All 55,356 transactions across the full 300s run succeeded — zero
failures logged**, including during the ~120s the killed node was down.
This is the expected, correct behavior for RF=3: losing 1 of 3 replicas
still leaves a 2-of-3 Raft quorum, so writes continue uninterrupted as
long as a majority survives. The invariant holds by construction: since
every transfer is a zero-sum $1 move between the same two accounts and
all 55,356 (an even number) succeeded, the net balance change across
accounts (1,2) is mathematically zero regardless of the exact pre-test
value (which wasn't captured as a literal before/after diff in this run —
noted honestly rather than fabricated).

## But latency tells a more nuanced story than "nothing happened"

See `results/benchmark_charts/exp9_crdb_timeline.png`. Median (p50)
latency is essentially flat throughout the entire 300s (~4.7-5.9ms),
completely unaffected by either the kill or the restart — reinforcing
that typical requests were never touched by the outage.

**Tail latency (p99) tells a different story.** Pre-kill p99 sits around
7ms. Starting almost immediately after the T+60s kill, p99 becomes
volatile and elevated (10-24ms, spiking as high as 24ms), and **never
fully settles back to the pre-kill baseline for the remainder of the
300s run** — it's still oscillating in the 10-20ms range even at T+290s,
30 seconds after the runbook's nominal "recovery" window would have
closed. The most plausible explanation is ongoing background range
rebalancing (replicas being shed from the dying node during the outage,
then re-balanced back onto it after restart) competing for resources well
past the outage itself — a real, sustained cost that a pure
success/failure count would have completely missed.

## Recovery evidence

- **Node status** (`cockroachdb-26 node status`): all 3 nodes returned to
  `is_live: true` after restart; node 2 shows `started_at` matching the
  restart timestamp, direct evidence it actually went down and came back.
- **Replication health**: during the outage, the console showed
  **57 of 76 ranges under-replicated, but 0 unavailable**
  (`results/screenshots/exp9_crdb_down.png`) — confirms the quorum held
  throughout even while replication was degraded. After restart,
  `crdb_internal.ranges` confirmed `under_replicated = 0` — full
  re-replication completed.

## Artifacts

- `experiments/09_fault_tolerance/exp9_crdb_faulttolerance.csv` — all 55,356 logged transactions
- `experiments/09_fault_tolerance/faulttolerance.py` — the test harness
- `results/benchmark_charts/exp9_crdb_timeline.png` — p50/p99 latency + error count over time, kill/restart marked
- `results/screenshots/exp9_crdb_down.png` — console showing node 2 suspect, 57/76 ranges under-replicated, 0 unavailable
