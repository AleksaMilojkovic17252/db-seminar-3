# Experiment 9 — Results — Spanner Omni (RF=3 redo, 2026-07-29)

## Headline: zero failures, and — unlike the other two — no latency cost either

| Metric | Value |
|---|---|
| Total transactions | **32,162** |
| Failed transactions | **0** |
| Median latency, whole run | flat, ~8.7–9.0 ms |
| p99 pre-kill baseline | ~14.7 ms |
| p99 after the kill | **never sustained** — stays 14–18 ms throughout every phase |
| Recovery | **automatic, ~61 s** (Kubernetes self-heal, unscheduled) |
| Balance invariant | held **exactly** — balances verified identical to seed values by direct query |

Per-phase breakdown:

| Phase | Transactions | p50 | p99 |
|---|---|---|---|
| Kill window, first 30 s (T+60–90) | 3,177 | 8.86 ms | 17.97 ms |
| Kill window, rest (T+90–180) | 9,682 | 8.83 ms | 15.36 ms |
| Post-recovery, first 60 s (T+180–240) | 6,410 | 8.72 ms | 15.94 ms |
| Post-recovery, last 60 s (T+240–300) | 6,496 | 8.76 ms | 14.38 ms |

Raw data: `experiments/09_fault_tolerance/exp9_spanner_faulttolerance.csv`.
Full write-up: `experiments/09_fault_tolerance/exp9_spanner_results.md`.
Chart: `results/benchmark_charts/exp9_spanner_timeline.png`.

## What it means

The zero-failure result matches CockroachDB and TiDB: at RF=3, losing 1 of 3
replicas leaves a Paxos majority, so writes continue.

The latency result does not match either of them. Where CockroachDB's p99
degraded immediately and TiDB's degraded after ~50 s — and **neither
recovered within the window** — Spanner's p50 and p99 stayed within baseline
noise across every phase, including the ~61 s the killed leader was actually
down.

The likely explanation: Spanner's Paxos group elected a new leader among the
two surviving root servers almost immediately, well before the killed pod
even finished rescheduling, so the outage was structurally invisible to
clients. **This is a plausible inference from the timeline, not confirmed
against internal election logs.**

## The two blips, and what caused them

The run was not perfectly flat. Two brief (1–2 s) latency blips appeared
well **after** recovery, at T+221 s and T+262 s. They were traced to a
**stale server registration** left over from Experiment 6's scale-out test:
Helm's scale-down removes the pod but does not deregister the server from
Spanner's internal directory. Cleared with
`spanner deployment servers delete`.

That is a real finding about Helm-based scale-down, not a fault-tolerance
weakness — and it is why Experiment 6's `05_cleanup.sh` matters.

## Do not turn this into a ranking (R3)

"Spanner recovers better than CockroachDB and TiDB" would overclaim badly.
Different deployment substrates (Kubernetes orchestration versus bare
processes), different topologies (Spanner's whole dataset lives in one Paxos
group per Experiment 1; the other two spread load across dozens of
ranges/regions), one laptop, one Preview build.

What *is* a defensible structural claim: recovery on CockroachDB and TiDB is
entirely operator-scheduled — the node comes back exactly when someone runs
the command — while Spanner Omni's Kubernetes-managed pods self-heal
automatically, here in about 61 seconds, with no manual step existing at all.
That is a difference in **how** recovery happens, not just how fast, and the
other two engines' bare-process deployment cannot exhibit it.
