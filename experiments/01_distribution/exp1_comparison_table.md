# Experiment 1 — Data Distribution: Comparison Table

Goal (per runbook): for each engine, record the name of the sharding unit, how
many units `orders` was split into, the replication factor actually observed,
and what decides placement — at equal replication factor where possible (R1).

**Update (2026-07-29):** Spanner's column below was originally single-server
(RF=1, qualitative-only, per R1) — see `spanner_omni_multiserver_task.md` and
`docs/spanner_multiserver_setup.md`. It has since been **redone against a
real 3-root-server Spanner Omni deployment** (local k3s, Helm chart
`spanner-omni:0.2.0`, database `seminar-multiserver`), so the Spanner column
now reports **real, replication-parity data** — the only one of experiments
1/6/9 rows in this doc that's been redone so far. CockroachDB/TiDB columns
are unchanged from the original run.

| | CockroachDB | TiDB | Spanner Omni (redone, multi-server) |
|---|---|---|---|
| **Unit name** | Range | Region | Split / group (`SPANNER_SYS.SPLIT_STATS_MINUTE`) |
| **Units for `orders`** | 1 (range_id 83) | 1 (region_id 301) | 1 (`group_uid 51380225`, shared with every other user table — same "everything fits in one shard at this scale" result as CRDB/TiDB, now directly confirmed for Spanner too) |
| **Replication factor** | 3 | 3 | **3** (3 root servers, `spanner-a-0/1/2`, all `root: true`, all `READY` — confirmed via `spanner deployment zones describe`/`servers list`) |
| **Replica placement** | 1 replica per locality: `eu-west/a`, `us-east/b`, `us-west/c` | 1 peer per store: stores 1, 2, 3 | Single-zone (`local-a`), all 3 root servers hold an **identical ~10GB on-disk footprint** (`du -sh /spanner` on each pod) — consistent with full replication of the one user-data group across all 3, not partitioning |
| **Leader / lease holder** | node 1 (lease_holder = 1) | store 3 (LEADER_STORE_ID = 3) | `spanner-a-1` (`generating_machine` field in `spanner admin alpha descriptor print seminar-multiserver 51380225` — confirmed identical when queried from both `spanner-a-0` and `spanner-a-2`, so this is the group's real leader, not just "whichever server answered") |
| **What decides placement** | CockroachDB's replication allocator (locality-aware, driven by `--locality` on each node) | PD (Placement Driver) | Spanner's placement driver — now actually observed in effect, not just "in principle" |
| **Table size observed** | ~3-5 MB (est.) | ~10 MB (`APPROXIMATE_SIZE(MB)` = 10) | not cleanly isolable per-table: `SPANNER_SYS.TABLE_SIZES_STATS_5MINUTE.LOGICAL_BYTES` returned 0 for every table (stats-collection lag in this Preview build, not a real zero — 50k/20k/5k/50k/120k/10 rows are verifiably present, see `experiments/rowcounts.txt`); ~10GB per-server on-disk footprint is the only size signal available, and it's whole-database, not per-table |

## The headline finding

**None of the three engines split `orders` into more than one unit at this
scale — and this is now confirmed for all three, not just two.** Both
CockroachDB and TiDB's default split thresholds are far above our reduced
seminar-scale table size (CockroachDB: 512 MiB, TiDB: ~96 MiB, `orders` is
only ~3-10 MB), and now that Spanner runs on 3 real root servers instead of
1, its own introspection (`SPANNER_SYS.SPLIT_STATS_MINUTE`) shows exactly the
same shape: every user table — `orders` included — lives in a single
non-system group (`group_uid 51380225`), with only one other group in the
whole deployment (a system-internal one holding no user tables). So
"distribution" for Experiment 1 is observed through **replica placement
across the 3 configured localities/stores/root-servers**, not through
range/region/split count, for all three engines — which is itself a
legitimate, explainable result: it shows the *threshold* behavior of
automatic sharding rather than sharding in action. A larger dataset would
cross that threshold and produce multiple ranges/regions/splits; ours
deliberately doesn't, per the runbook's Phase 2 size reduction for lab-scale
feasibility.

## Per-engine notes

**CockroachDB** — `crdb_internal` access required an explicit
`SET allow_unsafe_internals = true;` in-session (a session variable new in
v25.4+, defaulting to off, gating all `crdb_internal`/`system` access
regardless of user — logged to the `SENSITIVE_ACCESS` audit channel when
overridden). Worth a sentence in the paper as a small security-posture
observation distinct from TiDB/Spanner's approach to exposing internal state.

**TiDB** — the single region's `APPROXIMATE_KEYS` (130,294) is higher than
`orders`' 50,000 rows because TiDB auto-creates a secondary index to enforce
the `customer_id` foreign key, and both the row data and the FK index live in
the same region at this size (confirmed via `information_schema.tables` —
there is no separate table occupying the adjacent key space; TiDB simply
reserves alternating table IDs internally).

**Spanner Omni** — *originally* single-server (RF=1), a deliberate fallback
decision recorded in `results/env.txt` during Phase 1 (the documented
multi-server path targets GKE/EKS only, with no supported local k3s/kind
procedure at the time). That row was qualitative-only per R1.

**This has since been redone** against a real 3-root-server deployment
(local k3s + Helm, see `docs/spanner_multiserver_setup.md` for the full
setup — including two chart-specific bugs hit and fixed: a missing
`topology.kubernetes.io/zone` node label, and the chart's default hard pod
anti-affinity, which is unsatisfiable on a single-node cluster and had to be
overridden). The CLI's documented surface (`spanner databases splits`) still
only supports `add`, not `list` — same limitation as before — but the
**alpha** surface (`spanner admin alpha sql` against `SPANNER_SYS`, and
`spanner admin alpha descriptor print`) turned out to expose real
split/group/leader information that the documented CLI doesn't. Two things
worth flagging: (1) `SPANNER_SYS.TABLE_SIZES_STATS_5MINUTE` returned 0 bytes
for every table — a stats-collection lag in this Preview build, not a real
empty database (rows are independently verified present and correct-count),
so per-table size stays unmeasured even now; (2) the on-disk footprint
(~10GB/server) exceeds the `storage.data.size`/`storage.logs.size` Helm
overrides (5Gi/2Gi) requested during setup — k3s's `local-path`
StorageClass doesn't enforce PVC size as a real quota (it's a host-directory
binder, not a real capacity-limited volume plugin), so this isn't a bug, just
worth knowing if reproducing this deployment.

## Artifacts

- `experiments/01_distribution/exp1_crdb_ranges.txt` / `exp1_crdb_ranges_orders.txt`
- `experiments/01_distribution/exp1_tidb_regions.txt` / `exp1_tidb_regions_leader_store_id.txt` / `exp1_tidb_regions_tikv_region_peers.txt`
- `experiments/01_distribution/exp1_spanner_multiserver_topology.txt` — 3-server zone/server state (redo)
- `experiments/01_distribution/exp1_spanner_multiserver_splits.txt` — split/group introspection, leader confirmation, per-server disk footprint (redo)
- `results/screenshots/exp1_crdb_ranges.png`
- `results/screenshots/exp1_tidb_regions.png`
- `results/screenshots/exp1_spanner_splits.png` — **historical artifact from the original single-server run**, kept for the record; superseded by the two `.txt` files above (no UI screenshot for the redo — the multi-server deployment has `console.enabled=false`, so CLI text output is the artifact of record, same pattern as CockroachDB's Exp2 DistSQL screenshot gap noted in `CLAUDE.md`)
