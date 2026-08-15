#!/usr/bin/env bash
# Experiment 3 — Spanner Omni — commit latency, ORIGINAL single-server (RF=1)
# Run: bash run_bench_rf1.sh
#
# Stop CockroachDB and TiDB first (measurement isolation).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
export SPANNER_EMULATOR_HOST=localhost:15000
python3 experiments/03_transactions/bench_transactions.py --engine spanner

echo
echo "Appended rows with engine=spanner to experiments/03_transactions/exp3_latency.csv"
