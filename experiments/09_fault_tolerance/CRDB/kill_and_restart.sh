#!/usr/bin/env bash
# Experiment 9 — CockroachDB — the manual kill/restart steps.
#
# Two phases, ~120s apart, so this takes a subcommand rather than running
# both back to back. In a SECOND terminal, at the moments run.sh announces:
#
#   NODE2_PID=12345 bash kill_and_restart.sh kill      # at T+60s
#              bash kill_and_restart.sh restart        # at T+180s
#
# Find node 2's PID BEFORE the run starts:
#   ps aux | grep '[c]ockroachdb-26 start' | grep 26258
#
# Kill by explicit PID, never with `pkill -f` — during this project a
# `pkill -f` pattern matched the invoking shell's own command line and
# killed the wrong process.
set -euo pipefail

case "${1:-}" in
  kill)
    : "${NODE2_PID:?set NODE2_PID to the pid of node 2 first (see header)}"
    kill -9 "$NODE2_PID"
    echo "node 2 killed."
    echo "Now screenshot the DB Console -> Overview while it is down:"
    echo "  results/screenshots/exp9_crdb_down.png"
    echo "Expect: under-replicated ranges > 0, UNAVAILABLE ranges = 0."
    ;;

  restart)
    cd "$(git rev-parse --show-toplevel)"
    nohup cockroachdb-26 start --insecure --store=node2 \
      --locality=region=us-east,zone=b \
      --listen-addr=localhost:26258 --advertise-addr=localhost:26258 \
      --http-addr=localhost:8081 \
      --join=localhost:26257,localhost:26258,localhost:26259 \
      > node2.log 2>&1 &
    sleep 10
    cockroachdb-26 node status --insecure --host=localhost:26257
    echo
    echo "Expect all 3 nodes is_live = true, and node 2's started_at matching"
    echo "the restart — direct evidence it went down and came back."
    ;;

  *)
    echo "usage: NODE2_PID=<pid> bash $0 kill   |   bash $0 restart" >&2
    exit 2
    ;;
esac
