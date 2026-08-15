#!/usr/bin/env bash
# Experiment 3 — CockroachDB — commit latency benchmark
# Run: bash run_bench.sh
#
# Stop TiDB and Spanner first (measurement isolation, per the runbook and
# results/env.txt). 3 runs x 200 transactions, 30s idle between runs.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
python3 experiments/03_transactions/bench_transactions.py --engine crdb

echo
echo "Appended rows with engine=crdb to experiments/03_transactions/exp3_latency.csv"
