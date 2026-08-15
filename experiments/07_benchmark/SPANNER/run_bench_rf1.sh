#!/usr/bin/env bash
# Experiment 7 — Spanner Omni — concurrency sweep, single-server (RF=1)
# Run: bash run_bench_rf1.sh
#
# Stop CockroachDB and TiDB first.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
export SPANNER_EMULATOR_HOST=localhost:15000

python3 experiments/07_benchmark/bench.py --engine spanner \
  --conns 1,4,16,32,64 --duration 30 --reps 3
