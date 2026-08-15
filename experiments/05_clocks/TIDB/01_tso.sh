#!/usr/bin/env bash
# Experiment 5 — TiDB — centralised TSO (PD)
# Run: bash 01_tso.sh
#
# @@tidb_current_ts reads 0 outside a transaction (runbook T-18), so each
# read is wrapped in BEGIN; ... COMMIT;. Three separate invocations, so
# three separate connections and three separate transactions.
set -euo pipefail

for i in 1 2 3; do
  mariadb -h 127.0.0.1 -P 4000 -u root -D seminar \
    -e "BEGIN; SELECT @@tidb_current_ts; COMMIT;"
done

# `mysql` works identically in place of `mariadb`.
