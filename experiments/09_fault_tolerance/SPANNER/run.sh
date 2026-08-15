#!/usr/bin/env bash
# Experiment 9 — Spanner Omni — fault tolerance under load (RF=3)
# Run: bash run.sh
#
# Stop CockroachDB and TiDB first. Run Experiment 6's 05_cleanup.sh first if
# the 4th server is still registered.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate
export SPANNER_EMULATOR_HOST=localhost:30010

python3 experiments/09_fault_tolerance/faulttolerance.py --engine spanner

echo
echo "Chart it:"
echo "  python3 experiments/09_fault_tolerance/make_charts.py --engine spanner"
