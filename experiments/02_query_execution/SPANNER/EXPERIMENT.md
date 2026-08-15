# Experiment 2 — Query Execution — Spanner Omni

## What this experiment does

The query is the same logical statement on all three engines: *total order
value per region, for a product category, rating >= 4* — a four-table join
(`orders` + `customers` + `order_items` + `products`) aggregated by region.
All three dialect variants live in `experiments/02_query_execution/query.sql`.

Spanner's dialect variant differs in exactly one place: `order_items.id`
**is** the parent order's id (an interleaving requirement — see
`schema/schema_googlesql.sql`), so the join condition is `oi.id = o.id`
rather than `oi.order_id = o.id`. Everything else is identical.

The experiment was run twice:

- **RF=1**, against the original single-server container, database `seminar`.
- **RF=3 (partial redo, 2026-07-29)**, against the 3-root-server k3s
  deployment, database `seminar-multiserver` — specifically to test the
  original write-up's explicitly-untested claim that distribution "would
  happen the same way" on a multi-server deployment.

## Prerequisites

- RF=1 path: `docker start spanneromni`.
- RF=3 path: `bash setup/start_spanner_multiserver.sh`.

## Files, in run order

| # | File | How to run |
|---|---|---|
| 1 | `01_profile_rf1.sh` | `bash 01_profile_rf1.sh` — original single-server run |
| 2 | `02_profile_rf3.sh` | `bash 02_profile_rf3.sh` — the RF=3 redo |

Run 1 before 2 if reproducing the comparison from scratch; they are
independent otherwise (different databases, different deployments).

## Gotcha that shaped every Spanner command in this project

This Omni beta's CLI **cannot parse multi-line `--sql` values**. A perfectly
valid multi-line query fails with a generic, unhelpful
`Error: failed to build statement: invalid statement`. Flattening the exact
same query onto one line fixes it immediately. It is a CLI-parsing quirk,
not a SQL problem — and it is why every Spanner query in this repo is
written on a single line.

## Artifacts of record

- `experiments/02_query_execution/exp2_spanner_plan.txt` (full transcript, RF=1)
- `experiments/02_query_execution/exp2_spanner_plan.json` (extracted plan with executionStats)
- `experiments/02_query_execution/exp2_spanner_multi_plan.txt` (RF=3 redo)
- `results/screenshots/exp2_spanner_plan.png` (Query Insights)
