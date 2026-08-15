#!/usr/bin/env bash
# Experiment 3 — Spanner Omni — commit latency, 3-root-server (RF=3 redo)
# Run: bash run_bench_rf3.sh
#
# Writes under the SEPARATE engine label `spanner_multi`, so the original
# RF=1 rows in exp3_latency.csv are preserved rather than overwritten.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
export SPANNER_EMULATOR_HOST=localhost:30010
python3 experiments/03_transactions/bench_transactions.py --engine spanner_multi

echo
echo "Appended rows with engine=spanner_multi to experiments/03_transactions/exp3_latency.csv"
