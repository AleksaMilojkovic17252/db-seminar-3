#!/usr/bin/env bash
# Experiment 9 — TiDB — fault tolerance under load
# Run: bash run.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
python3 experiments/09_fault_tolerance/faulttolerance.py --engine tidb

echo
echo "Chart it:"
echo "  python3 experiments/09_fault_tolerance/make_charts.py --engine tidb"
