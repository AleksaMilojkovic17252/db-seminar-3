# Experiment 5 — Results — Spanner Omni

## Measured

```
id           created_at
9999999999   2026-07-28T15:56:31.771422Z
```

The placeholder `PENDING_COMMIT_TIMESTAMP()` was replaced by an actual
timestamp assigned **at commit time by Spanner itself**, not supplied by the
client.

Raw output: `experiments/05_clocks/exp5_spanner_commit_timestamp.txt`.

## What it means

| Property | Spanner Omni |
|---|---|
| Mechanism | TrueTime + commit-wait — **software-defined** on Omni |
| Centralisation | not applicable in the HLC/TSO sense — the timestamp is assigned server-side at commit, and the transaction is held until the uncertainty interval has passed |
| Hardware requirement | **none on Omni**; GPS receivers and atomic clocks in production Spanner |
| Cost paid | commit-wait on every write |

In production Spanner this timestamp is chosen using TrueTime and the
transaction is held — commit-wait — until TrueTime's uncertainty interval
has definitely passed. That guarantees external consistency: any transaction
that later observes this one's effects is guaranteed to see a commit
timestamp genuinely in the past relative to its own start.

## R2 — the caveat, and why it is also a finding

> Spanner Omni implements a software-defined TrueTime rather than the
> GPS/atomic-clock TrueTime described in Corbett et al. (2012). The
> behaviour observed here therefore illustrates the commit-wait mechanism
> but not the uncertainty bounds of a production Spanner deployment.

That caveat is mandatory wherever a Spanner timing number appears. But it is
worth more than a footnote, and belongs in the paper's trends chapter:

The TrueTime-vs-HLC distinction was **the** central design argument
CockroachDB made against Spanner's original architecture — that HLC gets you
most of Spanner's guarantees using only NTP-grade synchronisation, without
requiring specialised hardware in every datacentre. If a software-defined
clock can now stand in for TrueTime well enough to run Omni's commit-wait
protocol, the *hardware* half of that argument has narrowed.

With one honest limit: Omni here is a Preview build on a single machine.
This does not settle what a software-defined TrueTime's uncertainty bounds
look like at real multi-datacentre scale — only that the mechanism no longer
strictly requires atomic clocks in order to exist.
