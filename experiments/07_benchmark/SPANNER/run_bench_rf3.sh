#!/usr/bin/env bash
# Experiment 7 — Spanner Omni — concurrency sweep, 3-root-server (RF=3)
# Run: bash run_bench_rf3.sh
#
# Stop CockroachDB and TiDB first. Writes under the separate `spanner_multi`
# label so the RF=1 series stays intact.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
export SPANNER_EMULATOR_HOST=localhost:30010

python3 experiments/07_benchmark/bench.py --engine spanner_multi \
  --conns 1,4,16,32,64 --duration 30 --reps 3
