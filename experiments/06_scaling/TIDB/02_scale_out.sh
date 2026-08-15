#!/usr/bin/env bash
# Experiment 6 — TiDB — add a 4th TiKV store to the LIVE playground
# Run: bash 02_scale_out.sh   (from a SECOND terminal — leave the playground
#                              running in the first one)
#
# Do NOT restart the playground. The runbook's T-19 restart fallback would
# destroy the before/after comparison; `scale-out` is available in this
# TiUP version (confirmed via `tiup playground --help`).
set -euo pipefail

tiup playground scale-out --kv 1

sleep 15
echo
echo "## New store should now appear, state Up:"
mariadb -h 127.0.0.1 -P 4000 -u root \
  -e "SELECT store_id, address, store_state_name FROM information_schema.tikv_store_status;"

echo
echo "Wait for PD to rebalance, then run 03_after.sql."
