#!/usr/bin/env bash
# Experiment 2 — Spanner Omni — SAME query against the 3-root-server RF=3
# deployment (the partial redo, 2026-07-29).
# Run: bash 02_profile_rf3.sh
#
# The number to watch is `remote_server_calls` in the query stats: at RF=1
# it is trivially 0/0 because there is no second server to call.
set -euo pipefail

NS=spanner-ns
DB=seminar-multiserver

Q="SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value FROM orders o JOIN customers c ON o.customer_id = c.id JOIN order_items oi ON oi.id = o.id JOIN products p ON oi.product_id = p.id WHERE p.category = 'Electronics' AND p.rating >= 4 GROUP BY c.region ORDER BY c.region"

kubectl exec spanner-a-0 -n "$NS" -- /google/spanner/bin/spanner \
  databases execute-sql "$DB" --query-mode=PROFILE --sql="$Q"
