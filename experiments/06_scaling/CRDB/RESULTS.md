# Experiment 6 — Results — CockroachDB

## Lease holders — the fast signal

**Before** (3 nodes, 57 ranges total):

| Node | 1 | 2 | 3 |
|---|---|---|---|
| Lease-holder count | 18 | 19 | 20 |

**After** (~60 s later, 4 nodes):

| Node | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| Lease-holder count | 13 | 15 | 16 | **13** |

Total ranges: still **57** — no splits were triggered, the same threshold
result as Experiment 1. Node 4 reached close to an even quarter share within
about a minute.

## Replicas — the slow signal

From the DB Console after scale-out
(`results/screenshots/exp6_crdb_rebalance.png`), the **Replicas** column —
actual data copies, not query routing — reads:

| Node | a | b | c | d |
|---|---|---|---|---|
| Replicas | 28 | 57 | 57 | 29 |

Nodes b and c still hold a full replica of every one of the 57 ranges; the
new node d, and node a, hold roughly half. `Under-replicated ranges = 0` and
`Unavailable ranges = 0` throughout.

## What it means

Scale-out is not one instantaneous event. It is **at least two
independently-paced processes**:

- **Lease-holder rebalancing** — fast, metadata-only. It changes which node
  answers queries for a range, and it moved almost immediately.
- **Replica rebalancing** — slow, because it requires physically copying
  range data between nodes. It lagged well behind.

No range ever dropped below its required 3 replicas during the transition,
so this is a pacing difference, not a correctness gap. Worth a sentence in
the paper: the routing layer converges before the storage layer does, and a
metric that only watches one of them will tell you rebalancing finished
before it did.

Full write-up: `experiments/06_scaling/before_after.md`.
