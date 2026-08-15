#!/usr/bin/env bash
# Experiment 5 — Spanner Omni — commit timestamp and commit-wait
# Run: bash 01_commit_timestamp.sh
#
# PENDING_COMMIT_TIMESTAMP() is a placeholder: Spanner substitutes the
# timestamp it assigns at commit. ledger.created_at is declared
# OPTIONS (allow_commit_timestamp=true) in schema/schema_googlesql.sql.
#
# Single-line --sql values only — this Omni beta's CLI cannot parse
# multi-line ones.
set -euo pipefail

echo "## Write a row with a server-assigned commit timestamp"
docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
  --sql="INSERT INTO ledger (id, from_acct, to_acct, amount, created_at) VALUES (9999999999, 1, 2, 0.01, PENDING_COMMIT_TIMESTAMP())"

echo
echo "## Read it back — created_at is now a real timestamp, chosen by Spanner"
docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
  --sql="SELECT id, created_at FROM ledger WHERE id = 9999999999"
