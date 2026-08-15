# Experiment 1 — Data Distribution — TiDB

## What this experiment does

Records TiDB's unit of sharding (**region**), how many regions the `orders`
table occupies, the replication factor in effect, and which store leads the
region. The cluster runs `--kv 3`, i.e. three TiKV stores, giving RF=3 to
match CockroachDB (runbook rule R1).

## Prerequisites

TiDB playground up and seeded (`bash setup/start_tidb.sh`, which pins
`--tag VQajpo8` — dropping the tag creates an empty cluster). See
`docs/daily_startup.md`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_regions.sql` | `mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_regions.sql` |

`mariadb` works identically in place of `mysql` on CachyOS.

## Gotcha that cost time

The runbook's suggested column `leader_store_id` **does not exist** in
`information_schema.tikv_region_status` on TiDB v8.5.7 —
`Unknown column 'leader_store_id'`. Leader information actually lives in
`information_schema.tikv_region_peers`, as an `IS_LEADER` flag, joined back
on `region_id`. The script below uses the working form.

## Artifacts of record

- `experiments/01_distribution/exp1_tidb_regions.txt`
- `experiments/01_distribution/exp1_tidb_regions_leader_store_id.txt`
- `experiments/01_distribution/exp1_tidb_regions_tikv_region_peers.txt`
- `results/screenshots/exp1_tidb_regions.png`
