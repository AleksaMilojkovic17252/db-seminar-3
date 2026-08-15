#!/usr/bin/env bash
# Experiment 8 — TiDB — the actual HTAP claim: does OLTP survive OLAP load?
# Run: bash run_htap_isolation.sh
#
# Two measurements of the SAME OLTP workload — once quiet, once with the
# analytical query looping in a second process. The delta is the result;
# the MPP plan on its own is not.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
source .venv/bin/activate

echo "## Baseline: OLTP with no analytical load"
python3 experiments/07_benchmark/bench.py --engine tidb \
  --conns 16 --duration 20 --reps 1 \
  --workloads point_read,point_write \
  --csv-path experiments/08_standouts/exp8_tidb_htap_oltp.csv

echo
echo "## Now with concurrent OLAP load"
python3 experiments/08_standouts/htap_load.py --duration 60 &
HTAP_PID=$!
sleep 3

python3 experiments/07_benchmark/bench.py --engine tidb \
  --conns 16 --duration 20 --reps 1 \
  --workloads point_read,point_write \
  --csv-path experiments/08_standouts/exp8_tidb_htap_oltp.csv

wait $HTAP_PID || true
echo
echo "Compare the two sets of rows in experiments/08_standouts/exp8_tidb_htap_oltp.csv"
