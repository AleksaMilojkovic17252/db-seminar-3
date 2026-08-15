# Experiment 9 — Fault Tolerance: Spanner Omni (multi-server redo)

**Method:** continuous single-threaded transfer loop (alternating debit/credit
between accounts 1 and 2), 300s total — same protocol shape as CockroachDB/
TiDB, run via `faulttolerance.py --engine spanner` against the 3-root-server
deployment (`docs/spanner_multiserver_setup.md`), database
`seminar-multiserver`.

One real methodological difference from CockroachDB/TiDB, flagged up front:
those two are bare processes the operator manually starts and stops on a
fixed schedule (kill at T+60s, restart at T+180s). Spanner Omni's root
servers are Kubernetes StatefulSet pods with automatic self-healing — there
is no "restart the node" step to trigger manually; a killed pod comes back
on its own, on Kubernetes' schedule, not the runbook's. So this redo kills
the leader (`spanner-a-1`) at T+60s and **observes** recovery timing rather
than **triggering** it at T+180s.

```fish
kubectl delete pod spanner-a-1 -n spanner-ns --grace-period=0 --force
```

## Headline result: zero transaction failures, and — unlike CockroachDB or TiDB — no measurable latency degradation either

**All 32,162 transactions across the full 300s run succeeded — zero
failures logged**, including during the ~61s the killed leader was actually
down. That much matches CockroachDB (0/55,356 failed) and TiDB (0/46,812
failed): at RF=3, losing 1 of 3 replicas leaves a Paxos majority (2 of 3),
so writes continue uninterrupted.

**But latency tells a genuinely different story than either of the other
two engines.** p50/p99 stayed essentially flat across every phase of the
run:

| Window | n | p50 | p99 |
|---|---|---|---|
| Baseline (T+0-60s) | 6,396 | 9.00ms | 14.71ms |
| Kill window, first 30s (T+60-90s) | 3,177 | 8.86ms | 17.97ms |
| Kill window, rest (T+90-180s) | 9,682 | 8.83ms | 15.36ms |
| Post-recovery, first 60s (T+180-240s) | 6,410 | 8.72ms | 15.94ms |
| Post-recovery, last 60s (T+240-300s) | 6,496 | 8.76ms | 14.38ms |

No sustained p99 climb, no failure to recover — the whole run looks like
baseline noise. This is the opposite of what CockroachDB (p99 degrades
almost immediately, never fully recovers by T+300) and TiDB (p99 degrades
~50s after the kill, still noisy/elevated at T+300) showed.

**Recovery of the killed pod itself was fast: ~61 seconds**, observed
directly via `kubectl get pods -n spanner-ns -w`:
```
spanner-a-1   1/1   Terminating   ...
spanner-a-1   0/1   Pending             0s
spanner-a-1   0/1   ContainerCreating   1s
spanner-a-1   0/1   Running             1s
spanner-a-1   0/1   Running             41s
spanner-a-1   1/1   Running             61s
```
That's roughly half of CockroachDB/TiDB's fixed 120s manual-outage window
— and entirely automatic. The most plausible explanation for "zero
failures *and* zero latency impact" together is that the 3-server Paxos
group elected a new leader among the 2 surviving root servers (`spanner-a-0`/
`spanner-a-2`) almost immediately after the kill — well before `spanner-a-1`
itself finished being rescheduled — so client-visible service was never
actually interrupted; `spanner-a-1`'s ~61s of downtime was invisible to
callers because it wasn't on the critical path once a new leader took over.
This is inferred from the timeline, not independently confirmed against
internal Paxos election logs — flagged as a hypothesis, same caution the
project applied to TiDB's delayed-degradation timing in this same
experiment originally.

## Two small, transient latency blips — well after recovery, not during the outage

The raw per-transaction data isn't perfectly flat: two brief spikes appear,
both **after** `spanner-a-1` was already back and `Ready`:

- **T+221.0-223.3s** (~2.3s): 18 transactions between 22-98ms (vs. ~9ms
  baseline), peaking at 97.8ms — roughly 10x baseline, but still all
  **successful**.
- **T+261.8-262.4s** (~0.6s): 7 transactions between 34-83ms, same pattern.

Both are isolated, short-lived, and fully self-resolving within a couple of
seconds — nothing like CockroachDB/TiDB's sustained, never-fully-recovering
p99 elevation. **A plausible (not confirmed) explanation surfaced during
this redo's own housekeeping:** `spanner deployment servers list` still
showed a *stale* registration for `spanner-a-3` — a 4th, non-root server
added and later removed during Experiment 6 — as `READY`, even though that
pod and its PVCs had been fully deleted beforehand. Scaling a server down
via Helm (`replicasPerZone` 4→3) removes the pod but does **not**
automatically deregister it from Spanner's own internal server directory;
that requires an explicit `spanner deployment servers delete
<host:port> --zone=<zone>`, which hadn't been run yet at the time of this
test. If some periodic internal housekeeping (placement/health reconciliation)
tried and timed out reaching the phantom `spanner-a-3` around T+221s and
T+262s, that would explain two isolated multi-second blips with no other
correlated cause (they don't line up with the kill at T+60s or the recovery
at ~T+122s). The stale registration has since been cleaned up
(`spanner deployment servers delete spanner-a-3.pod.spanner-ns:15000
--zone=local-a --quiet`) but this run's data predates that cleanup — worth
a footnote in the paper rather than a confirmed causal claim.

## Balance invariant: exact, not just approximate

Accounts 1 and 2 currently read `63978.74` / `74180.89` —
**exactly** their original seed values
(`schema/seed_spanner.sql`: `(1, 'Owner_000001', 63978.74, ...)`,
`(2, 'Owner_000002', 74180.89, ...)`). With 32,162 transactions (an even
number, alternating debit direction) and zero failures, the net transfer
across the pair is exactly zero by construction — confirmed by direct
query, not just inferred from the transaction count the way CockroachDB's
write-up had to (that run didn't capture a literal before/after diff).

## Recovery/replication evidence

- `spanner deployment servers list --zone local-a`: all 3 root servers
  `READY` after the run (`spanner-a-0/1/2`), `spanner-a-1` specifically
  back with `0` restarts on its new pod incarnation (new pod, same
  StatefulSet identity, `AGE` reset to reflect the recreation).
- `descriptor print seminar-multiserver 51380225`'s `generating_machine`
  field now shows **three** distinct machines (`spanner-a-0`, `spanner-a-1`,
  `spanner-a-2`) across the tablet's storage generations, where before the
  kill it showed only `spanner-a-1` — direct evidence the group's
  leadership/generation genuinely moved during this test, not just a
  same-leader restart.

## Artifacts

- `experiments/09_fault_tolerance/exp9_spanner_faulttolerance.csv` — all 32,162 logged transactions
- `experiments/09_fault_tolerance/faulttolerance.py` — shared test harness (extended this session with a `spanner` engine branch, `google-cloud-spanner` client against `localhost:30010`)
- `results/benchmark_charts/exp9_spanner_timeline.png` — p50/p99 latency + failure count over time, kill/recovery marked
