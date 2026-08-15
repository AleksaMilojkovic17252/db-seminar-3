#!/usr/bin/env bash
# Experiment 6 — Spanner Omni — "before" snapshot
# Run: bash 01_before.sh
set -euo pipefail

NS=spanner-ns
DB=seminar-multiserver
SPANNER=/google/spanner/bin/spanner

echo "## Servers"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" deployment servers list --zone local-a

echo
echo "## Groups"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha sql "$DB" \
  "SELECT DISTINCT group_uid, is_system_split FROM SPANNER_SYS.SPLIT_STATS_MINUTE"

echo
echo "## Leader of the one user-data group"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha descriptor print "$DB" 51380225

echo
echo "## Disk footprint per server"
for p in spanner-a-0 spanner-a-1 spanner-a-2; do
  echo -n "$p: "; kubectl exec "$p" -n "$NS" -- du -sh /spanner | tail -1
done
