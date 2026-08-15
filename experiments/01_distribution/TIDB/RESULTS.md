# Experiment 1 — Results — TiDB

## Measured

| Property | Value |
|---|---|
| Unit name | Region |
| Regions holding `orders` | **1** (`region_id 301`) |
| Key span | `t_122_` → `t_124_` |
| Replication factor | **3** (peers `302, 303, 304`, one per store) |
| Replica placement | one peer per store: stores 1, 2, 3 |
| Leader | store 3 (`LEADER_ID 304`) |
| `APPROXIMATE_SIZE(MB)` | 10 |
| `APPROXIMATE_KEYS` | 130,294 |
| What decides placement | PD (Placement Driver) |

Raw output: `experiments/01_distribution/exp1_tidb_regions.txt`,
`exp1_tidb_regions_leader_store_id.txt`,
`exp1_tidb_regions_tikv_region_peers.txt`.

## What it means

`orders` occupies exactly one region. TiDB's default region-split threshold
is around 96 MiB; the table is about 10 MB, so no split was triggered — the
same threshold result CockroachDB and Spanner Omni produced.

## Why `APPROXIMATE_KEYS` (130,294) exceeds the row count (50,000)

TiDB **auto-creates a secondary index** to enforce the `customer_id` foreign
key. Both the row data and that FK index live in the same region at this
size, so the key count covers both. Confirmed against
`information_schema.tables` — no separate table occupies the adjacent key
space; TiDB simply reserves alternating table IDs internally.

This auto-indexing behaviour is itself a three-way difference: TiDB and
Spanner both create FK indexes automatically, CockroachDB only *recommends*
one (see Experiment 2).
