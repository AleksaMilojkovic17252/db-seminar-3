# Experiment 1 — Results — Spanner Omni (RF=3 redo, 2026-07-29)

## Measured

| Property | Value |
|---|---|
| Unit name | Split, grouped into Paxos groups (`SPANNER_SYS.SPLIT_STATS_MINUTE`) |
| Groups in the whole deployment | **2** — `55574529` (system) and `51380225` (all user data) |
| Groups holding `orders` | **1** (`group_uid 51380225`) |
| Tables sharing that group | every user table: `accounts`, `customers`, `doctors`, `ledger`, `order_items`, `orders`, `products`, plus the auto-created FK indexes |
| Replication factor | **3** — root servers `spanner-a-0/1/2`, all `root: true`, all `READY` |
| Replica placement | single zone `local-a`; all 3 root servers hold an identical **~10 GB** on-disk footprint |
| Leader | `spanner-a-1` (`generating_machine`, confirmed identical when queried from both `spanner-a-0` and `spanner-a-2`) |
| Per-table size | **unmeasurable** — `TABLE_SIZES_STATS_5MINUTE.LOGICAL_BYTES` returns 0 for every table (Preview-build stats lag) |
| What decides placement | Spanner's placement driver — now actually observed in effect, not asserted |

Raw output: `experiments/01_distribution/exp1_spanner_multiserver_topology.txt`
and `exp1_spanner_multiserver_splits.txt`.

## What it means

The single-shard result now holds for all three engines, not just two.
Every user table — `orders` included — lives in one non-system group, and
that group is replicated identically across all three root servers rather
than partitioned between them. Querying the group descriptor from two
different servers returns the same leader, which rules out the weaker
reading that each server simply reported itself.

Confirming this mattered: at RF=1 there was structurally nothing to observe,
so the original write-up could only say placement was "not observable". The
redo turns that into a measurement.

## Two deployment facts worth knowing if reproducing

- The ~10 GB per-server footprint **exceeds** the `storage.data.size` /
  `storage.logs.size` Helm overrides requested during setup (5 Gi / 2 Gi).
  k3s's `local-path` StorageClass binds a host directory rather than
  enforcing a real capacity quota, so the PVC size is advisory only. Not a
  bug — but it will surprise anyone sizing disks from the Helm values.
- The documented `spanner databases splits` subcommand supports only `add`.
  All the introspection above came from the `admin alpha` surface.
