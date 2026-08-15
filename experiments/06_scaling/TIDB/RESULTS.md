# Experiment 6 — Results — TiDB

## Peers per store

**Before** (3 stores):

| Store | 1 | 2 | 3 |
|---|---|---|---|
| Peer count | 5 | 5 | 5 |

15 total peer-slots = 5 regions × RF 3, split evenly.

**After** (new store `3001` at `127.0.0.1:42847`):

| Store | 1 | 2 | 3 | 3001 (new) |
|---|---|---|---|---|
| Peer count | 2 | 3 | 5 | **5** |

## What it means

The new store jumped straight to 5 peers — the same load as the busiest
original store — while store 1 shed the most (5 → 2) and store 3 was left
completely untouched (5 → 5).

PD's balancer moved replicas noticeably more aggressively and less evenly
toward the new store than CockroachDB's allocator did toward node 4. The
honest caveat: there are only 5 regions in total here, so every single peer
move is a large percentage swing. This is not necessarily representative of
behaviour at production scale, and the paper should say so rather than
present it as a characterisation of PD.

What the result *does* support unambiguously: capacity was added to a
running cluster, data redistributed automatically, and no application change
or restart was involved.

Full write-up: `experiments/06_scaling/before_after.md`.
