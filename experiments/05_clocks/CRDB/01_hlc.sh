#!/usr/bin/env bash
# Experiment 5 — CockroachDB — Hybrid Logical Clock
# Run: bash 01_hlc.sh
#
# Three separate invocations = three separate client connections, with no
# shared transaction state. If the values still rise monotonically, the
# clock itself is advancing, not just a session counter.
#
# NOTE: it is `cluster_logical_timestamp()`, NOT
# `crdb_internal.cluster_logical_timestamp()` — the prefixed form does not
# exist in v26.2.0 (SQLSTATE 42883).
set -euo pipefail

for i in 1 2 3; do
  cockroachdb-26 sql --insecure --host=localhost:26257 \
    -e "SELECT cluster_logical_timestamp();"
done

echo
echo "Now screenshot: DB Console (http://localhost:8080)"
echo "  -> Metrics -> Dashboard: Runtime -> Clock Offset"
echo "  -> results/screenshots/exp5_crdb_clockoffset.png"
