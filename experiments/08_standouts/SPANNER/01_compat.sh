#!/usr/bin/env bash
# Experiment 8 — Spanner Omni — SQL compatibility probes
# Run: bash 01_compat.sh
#
# One statement per invocation (the CLI has no session state), single-line
# --sql values only. Some of these are EXPECTED to fail; the failure is the
# data point.
set -e   # NOT -e on the probes themselves: several are meant to error.

S() { docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql "$@" || true; }

echo "## 1. Window functions — EXPECTED TO FAIL on this Preview build"
S seminar --sql="SELECT id, RANK() OVER (PARTITION BY region ORDER BY balance DESC) AS r FROM accounts LIMIT 5"
S seminar --sql="SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM accounts LIMIT 5"

echo
echo "## 2. CTEs"
S seminar --sql="WITH top_regions AS (SELECT region, count(*) AS n FROM accounts GROUP BY region) SELECT * FROM top_regions ORDER BY n DESC LIMIT 5"

echo
echo "## 3. THEN RETURN (the GoogleSQL equivalent of RETURNING)"
S seminar --sql="UPDATE accounts SET balance = balance + 0 WHERE id = 1 THEN RETURN id, balance"

echo
echo "## 4. Foreign key enforcement — EXPECTED TO BE REJECTED"
S seminar --sql="INSERT INTO orders (id, customer_id, order_date, total) VALUES (999999999, 999999999, PENDING_COMMIT_TIMESTAMP(), 1.00)"

echo
echo "## 5. JSON access — GoogleSQL form"
S seminar --sql="SELECT JSON_VALUE(JSON '{\"key\":\"value\"}', '\$.key') AS extracted"

echo
echo "## 6. Upsert — WATCH THIS ONE: it replaces the WHOLE ROW"
S seminar --sql="SELECT id, owner, balance, region FROM accounts WHERE id = 1"
S seminar --sql="INSERT OR UPDATE INTO accounts (id, owner, balance, region) VALUES (1, 'OVERWRITTEN', 12345.00, 'nowhere')"
S seminar --sql="SELECT id, owner, balance, region FROM accounts WHERE id = 1"
# owner and region WILL have changed, even though only balance was meant to.

echo
echo "## 7. Stored procedure — EXPECTED TO FAIL (no procedural SQL in GoogleSQL DDL)"
docker exec -i spanneromni /google/spanner/bin/spanner databases ddl update seminar \
  --ddl="CREATE PROCEDURE noop_proc() BEGIN SELECT 1; END" || true
