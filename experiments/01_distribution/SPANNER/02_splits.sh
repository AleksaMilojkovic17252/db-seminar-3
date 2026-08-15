#!/usr/bin/env bash
# Experiment 1 — Spanner Omni — split/group introspection and leader identity
# Run: bash 02_splits.sh   (after 01_topology.sh)
set -euo pipefail

NS=spanner-ns
DB=seminar-multiserver
SPANNER=/google/spanner/bin/spanner

echo "## How many groups exist, and which are system-internal?"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha sql "$DB" \
  "SELECT DISTINCT group_uid, is_system_split FROM SPANNER_SYS.SPLIT_STATS_MINUTE"

echo
echo "## Which tables live in the one non-system group?"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha sql "$DB" \
  "SELECT affected_tables FROM SPANNER_SYS.SPLIT_STATS_MINUTE WHERE group_uid=51380225 LIMIT 1"

echo
echo "## Who leads that group? Ask two different servers — if both name the"
echo "## same machine, it is the real leader, not just whoever answered."
for pod in spanner-a-0 spanner-a-2; do
  echo "--- queried from $pod ---"
  kubectl exec "$pod" -n "$NS" -- "$SPANNER" admin alpha descriptor print "$DB" 51380225
done

echo
echo "## On-disk footprint per server — identical size implies full replication,"
echo "## not partitioning."
for pod in spanner-a-0 spanner-a-1 spanner-a-2; do
  echo -n "$pod: "
  kubectl exec "$pod" -n "$NS" -- du -sh /spanner | tail -1
done
