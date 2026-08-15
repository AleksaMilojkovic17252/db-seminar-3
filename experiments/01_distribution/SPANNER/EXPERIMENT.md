# Experiment 1 — Data Distribution — Spanner Omni

## What this experiment does

Records Spanner Omni's unit of sharding (**split**, grouped into Paxos
**groups**), how many groups hold `orders`, the replication factor, which
server leads the group, and the per-server on-disk footprint.

**This experiment was redone at RF=3 (2026-07-29).** The original run used
the single-server (RF=1) container, where placement is not observable at
all; it was reported qualitatively per rule R1. It has since been re-run
against a real 3-root-server deployment on local k3s
(`docs/spanner_multiserver_setup.md`), so the numbers below are genuine
replication-parity data.

## Prerequisites

Multi-server deployment up: `bash setup/start_spanner_multiserver.sh`, then
`kubectl get pods -n spanner-ns` should show `spanner-a-0/1/2` Running.
gRPC on `localhost:30010`, database `seminar-multiserver`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_topology.sh` | `bash 01_topology.sh` — confirms 3 root servers, all READY |
| 2 | `02_splits.sh` | `bash 02_splits.sh` — group count, table→group mapping, leader, disk footprint |

Both scripts shell into the pods with `kubectl exec`, because the Spanner
CLI ships inside the container image rather than on the host.

## Two gotchas worth keeping

1. The **documented** CLI surface is a dead end here: `spanner databases
   splits` supports only `add`, not `list`, so there is no supported way to
   enumerate splits. The **alpha** surface (`spanner admin alpha sql`
   against `SPANNER_SYS`, and `spanner admin alpha descriptor print`) does
   expose real split/group/leader information. `SPANNER_SYS` is a real,
   documented Cloud Spanner introspection schema, not something improvised.
2. `SPANNER_SYS.TABLE_SIZES_STATS_5MINUTE.LOGICAL_BYTES` returns **0 for
   every table** on this build — stats-collection lag in the Preview
   release, not an empty database (row counts are independently verified in
   `experiments/rowcounts.txt`). Per-table size therefore stays unmeasured;
   the ~10 GB per-server footprint is whole-database, not per-table.

## Artifacts of record

- `experiments/01_distribution/exp1_spanner_multiserver_topology.txt`
- `experiments/01_distribution/exp1_spanner_multiserver_splits.txt`
- `results/screenshots/exp1_spanner_splits.png` — **historical, single-server**;
  superseded by the two `.txt` files (the multi-server deployment had the
  console disabled at test time, so CLI text is the artifact of record)
