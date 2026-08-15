# Experiment 6 — Results — Spanner Omni (RF=3 redo, 2026-07-29)

## Attempt 1 — a 4th root server: **rejected**

`rootServersPerZone` 3 → 4 was refused by the chart's own validation, before
a single pod was created:

```
Error: UPGRADE FAILED: execution error at (spanner-omni/templates/validations.yaml:37:10):

[FATAL] Zone 'local-a' in location 'local' has '4' root servers configured.
The number of root servers must be an odd number between 1 and 9
(i.e. 1, 3, 5, 7, or 9)!
```

This is a structural finding, not a configuration mistake. Spanner Omni's
root servers form a **Paxos voting group**, which needs an odd member count
for majority quorum. You cannot go from 3 to 4 root servers at all — only
3 → 5. **Neither CockroachDB nor TiDB has any equivalent parity constraint**
on node or store count.

## Attempt 2 — a 4th non-root server: **accepted, but nothing moved**

`replicasPerZone` 3 → 4 with `rootServersPerZone` left at 3 was accepted.

| | Before | After |
|---|---|---|
| Servers | `spanner-a-0/1/2`, all root | + `spanner-a-3`, `root: false`, READY |
| Restarts of existing pods | — | **0** (AGE unchanged) |
| Groups | 2 (1 system, 1 user-data) | **still 2, same `group_uid`s** |
| User-data group leader | `spanner-a-1` | **still `spanner-a-1`** |
| `spanner-a-3` disk footprint | — | 10 G — **baseline, not data** |
| `spanner-a-3` answers queries? | — | yes (`COUNT(*) = 50000`) |

**No rebalancing occurred at all.** The group's placement policy is scoped
to root servers specifically, so a non-root server sits outside it entirely:
it joins the deployment, it serves queries, and it receives no data.

Raw output: `experiments/06_scaling/exp6_spanner_before.txt` and
`exp6_spanner_after.txt`.

## What it means

Spanner distinguishes two things CockroachDB and TiDB treat as one:
**adding capacity** and **adding voting capacity**. Adding capacity is live,
unrestricted, and zero-downtime — exactly like the other two engines.
Adding *voting* capacity is gated on quorum parity and cannot be done one
server at a time.

That difference is invisible at RF=1, which is why this experiment was worth
redoing rather than reporting as a limitation.

## Cleanup that turned out to matter

The 4th server was removed afterwards (pod + PVCs) to return to a clean
3-root-server state before Experiment 9. Helm's scale-down removes the pod
but **does not deregister the server** from Spanner's internal directory.
The leftover registration produced two unexplained 1–2 second latency blips
well after recovery in the fault-tolerance run, traced back to this and
cleared with `spanner deployment servers delete`.

Full write-up: `experiments/06_scaling/before_after.md`.
