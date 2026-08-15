# Experiment 9 — Fault Tolerance: Comparison

Originally only meaningful at RF=3 (CockroachDB and TiDB) — Spanner Omni
ran single-server (RF=1) with no second replica to kill, and was excluded
entirely per R1 rather than run as a degenerate/qualitative version.

**Update (2026-07-29):** Spanner has since been redone against a real
3-root-server deployment (`docs/spanner_multiserver_setup.md`) and is now
included below on equal replication-factor footing. See
`experiments/09_fault_tolerance/exp9_crdb_results.md`, `exp9_tidb_results.md`,
and `exp9_spanner_results.md` for the full per-engine write-ups.

**Method:** continuous single-threaded transfer loop (alternating
debit/credit between two fixed accounts), 300s total, all three via the
same harness (`faulttolerance.py`). CockroachDB/TiDB: one node/store
killed with `kill -9` at T+60s, manually restarted at T+180s (operator-
controlled throughout — bare processes, no orchestrator). Spanner Omni:
its root servers are Kubernetes-managed pods with automatic self-healing,
so there is no manual "restart" step to match — the leader (`spanner-a-1`)
was killed at T+60s (`kubectl delete pod ... --grace-period=0 --force`)
and recovery was **observed**, not triggered, on Kubernetes' own schedule.

| | CockroachDB | TiDB | Spanner Omni |
|---|---|---|---|
| Total transactions | 55,356 | 46,812 | 32,162 |
| Failed transactions | **0** | **0** | **0** |
| Median (p50) latency, whole run | flat ~4.7-5.9ms | flat ~5.5-7ms | flat ~8.7-9.0ms |
| p99 latency, pre-kill baseline | ~7ms | ~8ms | ~14.7ms |
| When p99 starts degrading | almost immediately after kill (T+60s) | ~50s after kill (starts ~T+110s) | **never sustained** — stays 14-18ms throughout every phase |
| p99 fully recovered by T+300s? | no — still 10-20ms | no — still noisy, 10-28ms | n/a — never left baseline range |
| Downed-node recovery | manual restart at T+180s (operator-controlled) | manual restart at T+180s (operator-controlled) | automatic, ~61s (Kubernetes self-heal, unscheduled) |
| Balance invariant | held (even txn count, zero-sum transfers) | held (even txn count, zero-sum transfers) | held **exactly** — balances verified identical to seed values by direct query |
| Replication/servers confirmed healthy after | yes (`under_replicated = 0`) | yes (store back to `Up`) | yes (`deployment servers list` — all 3 root servers `READY`) |

## Headline finding: all three showed zero failures, but Spanner's redo is the first to show effectively zero *latency* cost too

All three engines lost zero transactions across a combined ~134,000
transactions and three independent node/server failures — the core NewSQL
fault-tolerance promise, demonstrated directly rather than asserted, now
confirmed on all three engines at matched RF=3.

Where CockroachDB and TiDB both showed a **real, lingering tail-latency
cost** that a pure success/failure count would have missed entirely (p99
elevated and volatile for the rest of the run, never recovering to
baseline by T+300s), **Spanner Omni's redo showed neither** — p50 and p99
stayed within baseline noise across every phase of the run, including the
~61s the killed leader was actually down. The likely explanation: Spanner's
Paxos group elected a new leader among the 2 surviving root servers almost
immediately, well before the killed pod even finished rescheduling, so the
outage was structurally invisible to clients — see `exp9_spanner_results.md`
for the full reasoning (flagged there as a plausible inference from the
timeline, not independently confirmed against internal election logs).

Spanner's run wasn't perfectly flat, though: two brief (1-2s) latency
blips appeared well *after* recovery (T+221s, T+262s), traced to a stale
server registration left over from Experiment 6's scale-out test — a real
finding about Helm-based scale-down not auto-deregistering a server from
Spanner's internal directory, not a fault-tolerance weakness. Full detail
in `exp9_spanner_results.md`.

## Where the engines genuinely differ (not a ranking — R3)

1. **Timing of tail-latency degradation, CockroachDB vs. TiDB**: CockroachDB's
   p99 jumps almost immediately after the kill; TiDB's stays near baseline
   for roughly a minute before degrading. Plausibly different
   failure-detection/election-timeout defaults, but inferred from the
   observed timeline, not independently confirmed — flagged as a
   hypothesis for Chapter 5, not a settled fact.
2. **Recovery model, bare-process engines vs. Spanner Omni**: CockroachDB/TiDB
   recovery is entirely operator-scheduled (restart happens exactly when
   the operator runs the command); Spanner Omni's Kubernetes-managed pods
   self-heal automatically and considerably faster than the other two
   engines' fixed 120s manual window (~61s here) — a genuine architectural
   difference in *how* recovery happens, not just how fast, that the other
   two engines' bare-process deployment can't exhibit at all.
3. Framing any of this as "Spanner recovers better than CockroachDB/TiDB"
   would overclaim — different deployment substrates (Kubernetes
   orchestration vs. bare processes), different topologies (Spanner's
   whole dataset lives in one Paxos group per Experiment 1's redo; the
   other two spread load across dozens of ranges/regions), one laptop, one
   Preview build. R3 applies here as much as anywhere else in this project.

## Artifacts

- `experiments/09_fault_tolerance/exp9_crdb_faulttolerance.csv` / `exp9_tidb_faulttolerance.csv` / `exp9_spanner_faulttolerance.csv`
- `experiments/09_fault_tolerance/faulttolerance.py` — shared test harness (extended this session with a `spanner` engine branch)
- `experiments/09_fault_tolerance/make_charts.py` — timeline chart generator
- `results/benchmark_charts/exp9_crdb_timeline.png` / `exp9_tidb_timeline.png` / `exp9_spanner_timeline.png`
- `results/screenshots/exp9_crdb_down.png` / `exp9_tidb_down.png` (no Spanner screenshot — console UI wasn't enabled for this deployment at test time, CLI/CSV data is the artifact of record, same pattern as other CLI-only artifacts in this project)
- `experiments/09_fault_tolerance/exp9_crdb_results.md` / `exp9_tidb_results.md` / `exp9_spanner_results.md` — full per-engine write-ups
