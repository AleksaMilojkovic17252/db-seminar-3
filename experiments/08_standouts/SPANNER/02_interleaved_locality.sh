#!/usr/bin/env bash
# Experiment 8 — Spanner Omni — interleaved-table locality
# Run: bash 02_interleaved_locality.sh
#
# order_items is declared INTERLEAVE IN PARENT orders ON DELETE CASCADE in
# schema/schema_googlesql.sql, so each order's line items are stored
# co-located with the parent order row.
#
# Watch `remote_server_calls` and `rows_scanned` in the PROFILE stats.
set -euo pipefail

S() { docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar --query-mode PROFILE "$@"; }

echo "## Query A — join on the interleave key only"
S --sql="SELECT o.id, oi.item_id, oi.product_id, oi.quantity FROM orders o JOIN order_items oi ON oi.id = o.id LIMIT 20"

echo
echo "## Query B — join needing a column that only exists on `orders`,"
echo "## which forces a real join rather than allowing it to be eliminated"
S --sql="SELECT o.id, o.total, oi.item_id, oi.quantity FROM orders o JOIN order_items oi ON oi.id = o.id LIMIT 20"

echo
echo "## The control: the SAME query B against the non-interleaved twin table"
S --sql="SELECT o.id, o.total, oif.item_id, oif.quantity FROM orders o JOIN order_items_flat oif ON oif.id = o.id LIMIT 20"
