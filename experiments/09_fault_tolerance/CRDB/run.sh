#!/usr/bin/env bash
# Experiment 9 — CockroachDB — fault tolerance under load
# Run: bash run.sh
#
# 300s loop. The script announces when to kill and when to restart; do those
# in a SECOND terminal with kill_and_restart.sh.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
python3 experiments/09_fault_tolerance/faulttolerance.py --engine crdb

echo
echo "Chart it:"
echo "  python3 experiments/09_fault_tolerance/make_charts.py --engine crdb"
