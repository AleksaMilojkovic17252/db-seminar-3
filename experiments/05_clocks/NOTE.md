# Experiment 5 — Clocks & Timestamp Ordering: Note

## Required caveat (R2) — must also appear in §4.0, §4.3, §4.5, §4.9 of the paper

> Spanner Omni implements a software-defined TrueTime rather than the
> GPS/atomic-clock TrueTime described in Corbett et al. (2012). The
> behaviour observed here therefore illustrates the commit-wait mechanism
> but not the uncertainty bounds of a production Spanner deployment.

Every Spanner timestamp and commit-wait observation in this project — the
commit timestamp captured in `exp5_spanner_commit_timestamp.txt`, and the
Spanner latency figures in Experiment 3 — describes Omni's software clock
implementation, not production Spanner's TrueTime.

## Why this is worth a paragraph in Chapter 5, not just a caveat

The fact that Spanner can now be built and demonstrated (Preview-grade,
but functionally complete: `PENDING_COMMIT_TIMESTAMP()`, commit-wait
semantics, external consistency guarantees) **without** the GPS/atomic-clock
hardware infrastructure Google originally built to support it is itself an
interesting data point. The TrueTime-vs-HLC distinction was the central
design argument CockroachDB made against Spanner's original architecture:
HLC gets you most of the way to Spanner's guarantees using only NTP-grade
clock synchronization, without requiring specialized hardware in every
datacenter. If a software-defined clock can now stand in for TrueTime well
enough to run Omni's commit-wait protocol, the *hardware* half of that
original argument has narrowed — though it's worth noting Omni is a
Preview/single-machine deployment, so this doesn't settle what a
software-defined TrueTime's actual uncertainty bounds look like at real
multi-datacenter scale, only that the *mechanism* itself no longer
strictly requires atomic clocks to exist as code.

## Summary of what was actually observed

| Engine | Mechanism | Centralization | Evidence |
|---|---|---|---|
| CockroachDB | Hybrid Logical Clock (HLC) | None — each node computes locally, adjusted by observed peer timestamps | 3 monotonically increasing `cluster_logical_timestamp()` values; Clock Offset graph (`exp5_crdb_clockoffset.png`) shows 0-50µs offset across nodes |
| TiDB | Centralized Timestamp Oracle (TSO) in PD | Full — every transaction start is a round-trip to the single PD process | 3 monotonically increasing `@@tidb_current_ts` values, all issued by the one PD TSO |
| Spanner Omni | TrueTime + commit-wait (software-defined on Omni) | Not applicable in the HLC/TSO sense — timestamp assigned by the server at commit, transaction held until uncertainty passes | `PENDING_COMMIT_TIMESTAMP()` resolved to an actual server-assigned commit timestamp on read-back |

## Artifacts

- `experiments/05_clocks/exp5_crdb_timestamps.txt`
- `experiments/05_clocks/exp5_tidb_timestamps.txt`
- `experiments/05_clocks/exp5_spanner_commit_timestamp.txt`
- `results/screenshots/exp5_crdb_clockoffset.png`
