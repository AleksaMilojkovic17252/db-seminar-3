#!/usr/bin/env bash
# Experiment 2 — Spanner Omni — query plan, ORIGINAL single-server (RF=1)
# Run: bash 01_profile_rf1.sh
#
# The --sql value MUST be on one line: this Omni beta's CLI fails on
# multi-line values with `failed to build statement: invalid statement`.
set -euo pipefail

Q="SELECT c.region, SUM(oi.quantity * oi.unit_price) AS total_value FROM orders o JOIN customers c ON o.customer_id = c.id JOIN order_items oi ON oi.id = o.id JOIN products p ON oi.product_id = p.id WHERE p.category = 'Electronics' AND p.rating >= 4 GROUP BY c.region ORDER BY c.region"

docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
  --query-mode=PROFILE --sql="$Q"
