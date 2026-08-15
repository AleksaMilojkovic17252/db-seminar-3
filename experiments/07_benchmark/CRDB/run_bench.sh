#!/usr/bin/env bash
# Experiment 7 — CockroachDB — concurrency sweep
# Run: bash run_bench.sh
#
# Stop TiDB and Spanner first. 3 workloads x [1,4,16,32,64] threads x 3 reps
# x 30s = 45 measured combinations, roughly 25 minutes.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate

python3 experiments/07_benchmark/bench.py --engine crdb \
  --conns 1,4,16,32,64 --duration 30 --reps 3

# Smoke test first, if you want to check connectivity without committing
# 25 minutes (REMEMBER to delete its rows afterwards — they collide with
# the real sweep's rep labels):
#   python3 experiments/07_benchmark/bench.py --engine crdb --conns 1,4 --duration 3 --reps 1
