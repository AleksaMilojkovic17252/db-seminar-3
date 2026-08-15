# Experiment 6 — Scaling & Rebalancing: Before/After

**Method:** add one node/store to each *running* cluster — no restart of
existing nodes — and observe redistribution.

**Update (2026-07-29):** Spanner was originally single-server (RF=1) with
nothing to scale into, skipped and reported as a qualitative limitation per
R1. It has since been redone against a real 3-root-server deployment (see
`docs/spanner_multiserver_setup.md`) — attempted below, with a genuinely
different and more interesting outcome than CockroachDB/TiDB's, not a
simple repeat of their pattern.

## CockroachDB — added node 4 (`region=eu-west,zone=d`) to a live 3-node cluster

No restart: `cockroachdb-26 start ... --join=<existing 3 addresses>` against
the already-running cluster.

**Before** (`crdb_internal.ranges`, lease holders):

| Node | 1 | 2 | 3 |
|---|---|---|---|
| Lease-holder count | 18 | 19 | 20 |

Total: 57 ranges, 3 nodes.

**After** (~60s later):

| Node | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| Lease-holder count | 13 | 15 | 16 | 13 |

Total: still 57 ranges (no range splits triggered — same headline finding
as Experiment 1, the seminar-scale data is far below CockroachDB's default
512MiB split threshold), now spread across 4 nodes. Node 4 already holds
13 lease-holders, close to an even 1/4 share.

**Screenshot** (`results/screenshots/exp6_crdb_rebalance.png`, DB Console
→ Overview, captured post-scale-out): shows a second, slower-moving axis
of rebalancing not visible in the lease-holder numbers alone — the
**Replicas** column (actual data copies, not just query routing) reads
`a=28, b=57, c=57, d=29`. Nodes b and c still hold a full replica of
every one of the 57 ranges; the new node d (and node a) hold replicas of
only about half. `Under-replicated ranges = 0` and `Unavailable ranges = 0`
throughout, so no range ever dropped below its required 3 replicas during
the transition — this is **lease-holder rebalancing (fast, metadata-only,
changes which node answers queries for a range) outpacing replica
rebalancing (slow, requires physically moving range data)**, not a
correctness gap. Worth a sentence in the paper: elastic scale-out is not
a single instantaneous event, it's (at least) two independently-paced
processes.

## TiDB — added 1 TiKV store via live `scale-out`, no restart

`tiup playground scale-out --kv 1` against the running playground
(confirmed available in this TiUP version via `tiup playground --help`,
avoiding the runbook's T-19 restart fallback). New store `3001` came up
at `127.0.0.1:42847`.

**Before** (`information_schema.tikv_region_peers`, peer count per store):

| Store | 1 | 2 | 3 |
|---|---|---|---|
| Peer count | 5 | 5 | 5 |

15 total peer-slots = 5 regions × RF 3, evenly split (5 each).

**After:**

| Store | 1 | 2 | 3 | 3001 (new) |
|---|---|---|---|---|
| Peer count | 2 | 3 | 5 | 5 |

Store `3001` jumped straight to 5 — the same load as the busiest original
store — while store 1 dropped the most (5→2) and store 3 was left
untouched (5→5). PD's balancer moved replicas noticeably more
aggressively/unevenly toward the new store than CockroachDB's allocator
did toward node 4, at this small scale (5 regions total, so each single
peer move is a large percentage swing — not necessarily representative
of behavior at production scale).

**Screenshot:** Key Visualizer did not render a usable heatmap at this
scale — likely needs more write history/time than a small seminar dataset
accumulates quickly; noted as a real tooling limitation, not chased
further. Substituted **Cluster Info → Instances** as the artifact
(`results/screenshots/exp6_tidb_regions.png`), which confirms the 4th
TiKV instance (`127.0.0.1:42847`) is `Up`, with a visibly later start
time than the original 3 — direct evidence it was added to the live
cluster rather than the whole playground being restarted.

## Spanner Omni — redone against the real 3-root-server deployment

**Before:** 3 root servers (`spanner-a-0/1/2`, all `root: true`, `READY`),
one non-system data group (`group_uid 51380225`, containing every user
table — see Experiment 1's redo) led by `spanner-a-1`, ~10GB on-disk
footprint per server. Full snapshot: `exp6_spanner_before.txt`.

**Attempt 1 — add a literal 4th root server** (`deployment.rootServersPerZone`
3→4), matching the task doc's original phrasing most literally: **rejected**
by the chart's own validation, not by trial and error against docs.

Command run (against the live 3-server release from Phase 3 of
`docs/spanner_multiserver_setup.md`, no prior change to existing values):
```fish
helm upgrade spanner-omni oci://us-docker.pkg.dev/spanner-omni/charts/spanner-omni --version 0.2.0 \
  --namespace spanner-ns \
  --reuse-values \
  --set deployment.replicasPerZone=4 \
  --set deployment.rootServersPerZone=4
```
Result — rejected before touching the cluster at all (no pod was ever
created for this attempt):
```
Error: UPGRADE FAILED: execution error at (spanner-omni/templates/validations.yaml:37:10):

[FATAL] Zone 'local-a' in location 'local' has '4' root servers configured.
The number of root servers must be an odd number between 1 and 9
(i.e. 1, 3, 5, 7, or 9)!
```
This is a real, structural finding in its own right: Spanner Omni's root
servers form a Paxos voting group, which requires an odd member count for
majority quorum — you cannot go from 3 to 4 root servers in one step, only
3→5. CockroachDB and TiDB have no equivalent parity constraint on
node/store count.

**Attempt 2 — add a 4th server as non-root** (`replicasPerZone` 3→4,
`rootServersPerZone` stays 3): **accepted**.

Command run:
```fish
helm upgrade spanner-omni oci://us-docker.pkg.dev/spanner-omni/charts/spanner-omni --version 0.2.0 \
  --namespace spanner-ns \
  --reuse-values \
  --set deployment.replicasPerZone=4 \
  --set deployment.rootServersPerZone=3
```
Result:
```
Release "spanner-omni" has been upgraded. Happy Helming!
REVISION: 2
```
`spanner-a-3` joined live — existing pods `spanner-a-0/1/2` show unchanged
`AGE` and `0` restarts throughout, confirming zero-downtime, zero-restart
scale-out, same as CockroachDB/TiDB. Verified with:
```fish
kubectl get pods -n spanner-ns -o wide
```
Its startup log is explicit about its role:
```
Starting the server in K8s environment with root: false and
joinServers: [spanner-a-0.pod.spanner-ns spanner-a-1.pod.spanner-ns spanner-a-2.pod.spanner-ns]
```
(`kubectl logs spanner-a-3 -n spanner-ns --tail=10`)

**Before/after evidence-gathering commands** (run before Attempt 1 and again
after Attempt 2 completed, full output in `exp6_spanner_before.txt` /
`exp6_spanner_after.txt`):
```fish
kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner deployment servers list --zone local-a

kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner admin alpha sql seminar-multiserver \
  "SELECT DISTINCT group_uid, is_system_split FROM SPANNER_SYS.SPLIT_STATS_MINUTE"

kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner admin alpha descriptor print seminar-multiserver 51380225 \
  | grep "generating_machine" | sort -u

for p in spanner-a-0 spanner-a-1 spanner-a-2 spanner-a-3; do
  echo -n "$p: "; kubectl exec $p -n spanner-ns -- du -sh /spanner | tail -1
done

kubectl exec spanner-a-3 -n spanner-ns -- /google/spanner/bin/spanner databases execute-sql seminar-multiserver \
  --sql="SELECT COUNT(*) FROM orders"
```

**After — no rebalancing occurred**, unlike CockroachDB and TiDB:
- Same 2 groups, same `group_uid`s, as before the join.
- Same leader (`spanner-a-1`) for the user-data group.
- `spanner-a-3` itself can still answer a query against the database
  (`SELECT COUNT(*) FROM orders` → 50000) — it's reachable and functional,
  just not a participant in the existing group's placement.
- All 4 servers show an identical ~10GB `/spanner` footprint, including the
  brand-new `spanner-a-3` within ~2 minutes of joining — this is **not**
  evidence data was replicated there; per Experiment 1's redo, this
  multi-GB footprint appears to be a fixed baseline storage-segment
  preallocation independent of actual data volume (also observed there),
  so it shows up on a nearly-empty non-root server just as it does on the
  3 data-holding roots. Full snapshot: `exp6_spanner_after.txt`.

**Why this is the headline Spanner finding for this experiment, not a null
result:** the group's `placement.group_set` spec (inspected via
`descriptor print`, see Experiment 1's redo) scopes replica placement to
the zone's *root* servers specifically (`zone_name: ca.0001`, the root
zone) — a non-root server added via `replicasPerZone` sits outside that
placement policy entirely. This is a genuine architectural difference from
CockroachDB's allocator and TiDB's PD, both of which treat "add a node/
store" as "immediately eligible for load," full stop. In Spanner Omni,
"add capacity" and "add voting/data capacity" are two different actions,
and the odd-quorum constraint means the second one can't be done
one-server-at-a-time from an even starting point — the smallest live
change that actually changes voting membership is a 3→5 jump.

## Interpretation for the paper

CockroachDB and TiDB demonstrated genuine live elastic scale-out — new
capacity added to a running cluster with zero downtime, and both engines'
internal balancers began redistributing load without any manual range/
region assignment, no questions asked about node count parity. Spanner
Omni's redo shows a **third, structurally distinct pattern**: scale-out is
gated by Paxos quorum parity for root/voting servers (odd-only, so no
literal "add one" path once you're already at an odd count), and adding
non-voting capacity — the only kind of "add one" that *is* live-attachable
— doesn't participate in existing data placement at all. Three engines,
three different scaling models, not a two-vs-one split:

1. **CockroachDB exposed two independently-paced rebalancing signals**
   (lease-holders moved faster than replicas); TiDB's single
   `tikv_region_peers` metric only shows the equivalent of the *slower*
   of the two.
2. **TiDB's redistribution was more aggressive/uneven** than
   CockroachDB's in this specific run, though the very small number of
   total units (5 TiDB regions vs. 57 CockroachDB ranges) means each
   single move is a much larger percentage swing for TiDB — this is not
   a claim that PD's balancer is more aggressive than CockroachDB's
   allocator in general, just what was observed at this scale (R3-style
   caution applies here too).
3. **Spanner Omni's root-server quorum constraint is a hard architectural
   gate CockroachDB/TiDB don't have** — worth a paragraph on its own in
   the paper's discussion, not folded into the "did it rebalance" framing
   the other two invite.

## Artifacts

- `results/screenshots/exp6_crdb_rebalance.png`
- `results/screenshots/exp6_tidb_regions.png` (Cluster Info substituted for Key Visualizer, see note above)
- `experiments/06_scaling/exp6_spanner_before.txt` / `exp6_spanner_after.txt` (redo)
