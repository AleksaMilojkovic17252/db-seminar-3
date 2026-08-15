#!/usr/bin/env bash
# Experiment 6 — CockroachDB — add a 4th node to the LIVE cluster
# Run: bash 02_add_node4.sh
#
# No restart of nodes 1-3. The new node is given its own locality
# (region=eu-west,zone=d) to match the locality-aware setup the other three
# use (see results/env.txt).
#
# `--background` has been discouraged for several releases; nohup is the
# safe form.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

nohup cockroachdb-26 start --insecure --store=node4 \
  --locality=region=eu-west,zone=d \
  --listen-addr=localhost:26260 --advertise-addr=localhost:26260 \
  --http-addr=localhost:8083 \
  --join=localhost:26257,localhost:26258,localhost:26259 \
  > node4.log 2>&1 &

sleep 10
cockroachdb-26 node status --insecure --host=localhost:26257

echo
echo "Wait ~60s for rebalancing to settle, then run 03_after.sql."
