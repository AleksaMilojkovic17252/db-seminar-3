#!/usr/bin/env bash
# Experiment 1 — Spanner Omni — deployment topology (RF=3 check)
# Run: bash 01_topology.sh
set -euo pipefail

NS=spanner-ns
POD=spanner-a-0
SPANNER=/google/spanner/bin/spanner

echo "## Zone description — expect 3 root servers, state READY"
kubectl exec "$POD" -n "$NS" -- "$SPANNER" deployment zones describe local-a

echo
echo "## Server list — expect spanner-a-0/1/2, ROOT=true, STATE=READY"
# --zone is NOT optional despite what some examples imply.
kubectl exec "$POD" -n "$NS" -- "$SPANNER" deployment servers list --zone local-a
