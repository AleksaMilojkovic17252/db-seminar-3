#!/usr/bin/env bash
# Experiment 7 — TiDB — concurrency sweep
# Run: bash run_bench.sh
#
# Stop CockroachDB and Spanner first.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate

python3 experiments/07_benchmark/bench.py --engine tidb \
  --conns 1,4,16,32,64 --duration 30 --reps 3
