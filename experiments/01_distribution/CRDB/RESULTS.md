# Experiment 1 — Results — CockroachDB

## Measured

| Property | Value |
|---|---|
| Unit name | Range |
| Ranges holding `orders` | **1** (`range_id 83`) |
| Range span | `<before:/Table/106>` → `<after:/Max>` |
| Replication factor | **3** (`replicas {1,2,3}`, all voting) |
| Replica placement | one per locality: `region=eu-west,zone=a`, `region=us-east,zone=b`, `region=us-west,zone=c` |
| Lease holder | node 1 |
| Non-voting / learner replicas | none |
| Table size | ~3–5 MB (estimated) |
| What decides placement | CockroachDB's replication allocator, locality-aware, driven by `--locality` per node |

Raw output: `experiments/01_distribution/exp1_crdb_ranges.txt` and
`exp1_crdb_ranges_orders.txt`.

## What it means

`orders` was **not** split. CockroachDB's default range-split threshold is
512 MiB and the seeded table is roughly three to five megabytes, so the
engine had no reason to divide it. That is not a failed experiment — it is
the *threshold* behaviour of automatic sharding, observed directly. What is
genuinely distributed at this scale is **replication**: three copies of the
one range, one in each configured locality, with a single lease holder
answering reads.

The finding matches TiDB (1 region) and Spanner Omni (1 group), so the
conclusion is engine-independent: at seminar scale, distribution is visible
through replica placement, not through shard count.

## Secondary observation worth a sentence in the paper

CockroachDB gates internal introspection behind an audit-logged session
variable (`allow_unsafe_internals`, v25.4+), off by default even for `root`.
Neither TiDB's `information_schema` nor Spanner's `SPANNER_SYS` required an
equivalent opt-in. A small but real difference in security posture around
exposing internal state.
