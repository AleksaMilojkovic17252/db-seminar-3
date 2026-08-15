#!/usr/bin/env bash
# Experiment 3 — TiDB — commit latency benchmark
# Run: bash run_bench.sh
#
# Stop CockroachDB and Spanner first (measurement isolation).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
python3 experiments/03_transactions/bench_transactions.py --engine tidb

echo
echo "Appended rows with engine=tidb to experiments/03_transactions/exp3_latency.csv"
