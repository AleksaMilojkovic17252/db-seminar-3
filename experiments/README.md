# Experiments — per-engine reproduction guide

Each experiment folder now has three subfolders — **`CRDB/`**, **`TIDB/`**,
**`SPANNER/`** — and each of those contains the same three things:

| File | What it is |
|---|---|
| `EXPERIMENT.md` | what the experiment does on this engine, prerequisites, the files in **run order**, and the gotchas that cost time |
| one or more `.sql` / `.sh` files | the actual commands, numbered by the order they must run in |
| `RESULTS.md` | what came out, and what it means |

Nothing was moved. The cross-engine comparison docs (`exp1_comparison_table.md`,
`before_after.md`, `exp7_comparison.md`, …) and the raw `.txt`/`.csv`
artifacts stay exactly where they were, and remain the artifacts of record —
the per-engine `RESULTS.md` files cite them rather than replacing them.

## The map

| # | Folder | Cross-engine summary | Per-engine folders |
|---|---|---|---|
| 1 | `01_distribution/` | `exp1_comparison_table.md` | CRDB · TIDB · SPANNER |
| 2 | `02_query_execution/` | `exp2_comparison_table.md` | CRDB · TIDB · SPANNER |
| 3 | `03_transactions/` | `exp3_comparison_table.md` | CRDB · TIDB · SPANNER |
| 4 | `04_write_skew/` | `exp4_comparison_table.md` | CRDB (C3, C4) · TIDB (C1, C2, C2b) · SPANNER (C5) |
| 5 | `05_clocks/` | `NOTE.md` | CRDB · TIDB · SPANNER |
| 6 | `06_scaling/` | `before_after.md` | CRDB · TIDB · SPANNER |
| 7 | `07_benchmark/` | `exp7_comparison.md` | CRDB · TIDB · SPANNER (RF=1 and RF=3) |
| 8 | `08_standouts/` | `exp8_compatibility.md`, `exp8_tidb_htap.md` | CRDB · TIDB · SPANNER |
| 9 | `09_fault_tolerance/` | `exp9_comparison.md` | CRDB · TIDB · SPANNER |

## Shared harnesses

Four experiments are driven by multi-engine Python harnesses, which stay at
the experiment root rather than being copied per engine. The per-engine
folders contain a thin `run*.sh` with the exact invocation, so there is one
source of truth for the code that actually produced the numbers:

- `03_transactions/bench_transactions.py` — commit-latency harness
- `07_benchmark/bench.py` + `make_charts.py` — concurrency sweep
- `08_standouts/htap_load.py` — OLAP load generator for the HTAP isolation test
- `09_fault_tolerance/faulttolerance.py` + `make_charts.py` — kill/restart harness

All of them take `--engine` and connect to whichever engines are running on
their standard ports (TiDB 4000, CockroachDB 26257, Spanner Omni via
`SPANNER_EMULATOR_HOST`). Bring-up commands: `docs/daily_startup.md`.

## Which Spanner deployment each experiment used

Spanner Omni ran in two topologies over the life of the project, and this is
the single most important thing to get right when citing a Spanner number.

| Experiment | Spanner deployment | Note |
|---|---|---|
| 1 distribution | **RF=3** (k3s, 3 root servers) | redone 2026-07-29 |
| 2 query execution | **RF=1 and RF=3** | partially redone — the plan/query-stats check only |
| 3 transactions | **RF=1 and RF=3** | both series reported side by side |
| 4 write skew | RF=1 | not redone — isolation behaviour is RF-invariant |
| 5 clocks | RF=1 | not redone — clock mechanism is RF-invariant |
| 6 scaling | **RF=3** | redone; originally skipped entirely |
| 7 benchmark | **RF=1 and RF=3** | both series reported side by side |
| 8 standouts | RF=1 | not redone — see `08_standouts/SPANNER/EXPERIMENT.md` for why the locality demo specifically was left alone |
| 9 fault tolerance | **RF=3** | redone; originally excluded entirely |

The three not redone were **checked** rather than assumed: isolation level,
clock mechanism and SQL dialect support have no replication dependency.

## The three rules that constrain how any of this is written up

- **R1 — replication parity.** CockroachDB and TiDB ran at RF=3 throughout.
  Spanner's deployment varies by experiment; see the table above and state
  which one produced each number.
- **R2 — Spanner Omni's TrueTime is software-defined**, not the GPS/atomic-clock
  TrueTime of Corbett et al. (2012). This applies to every Spanner timing
  observation in Experiments 3, 5 and 7.
- **R3 — no cross-engine performance ranking.** Three engines, different
  internal topologies, one laptop, one Preview build. Experiments 7 and 9
  characterise each engine's own response, never "X beat Y."

Full methodology: `seminar3_experiment_runbook.md` at the repo root.
