#!/usr/bin/env bash
# Experiment 6 — Spanner Omni — "after" snapshot
# Run: bash 04_after.sh   (give the new server time to join first)
set -euo pipefail

NS=spanner-ns
DB=seminar-multiserver
SPANNER=/google/spanner/bin/spanner

echo "## Servers — expect spanner-a-3 present, ROOT=false"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" deployment servers list --zone local-a

echo
echo "## Groups — expect UNCHANGED (same count, same group_uids)"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha sql "$DB" \
  "SELECT DISTINCT group_uid, is_system_split FROM SPANNER_SYS.SPLIT_STATS_MINUTE"

echo
echo "## Leader — expect UNCHANGED (still spanner-a-1)"
kubectl exec spanner-a-0 -n "$NS" -- "$SPANNER" admin alpha descriptor print "$DB" 51380225

echo
echo "## Disk footprint — the new server should hold baseline, not data"
for p in spanner-a-0 spanner-a-1 spanner-a-2 spanner-a-3; do
  echo -n "$p: "; kubectl exec "$p" -n "$NS" -- du -sh /spanner | tail -1
done

echo
echo "## But it does answer queries — it is a working server, just not a placement target"
kubectl exec spanner-a-3 -n "$NS" -- "$SPANNER" databases execute-sql "$DB" \
  --sql="SELECT COUNT(*) FROM accounts"
