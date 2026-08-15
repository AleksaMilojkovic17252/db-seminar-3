#!/usr/bin/env bash
# Experiment 9 — TiDB — the manual kill/restart steps.
#
# Two phases, ~120s apart, so this takes a subcommand rather than running
# both back to back. In a SECOND terminal, at the moments run.sh announces:
#
#   STORE1_PID=12345 bash kill_and_restart.sh kill     # at T+60s
#               bash kill_and_restart.sh verify        # at T+180s and after
#
# Find TiKV store 1's PID (127.0.0.1:20160) BEFORE the run starts:
#   ps aux | grep '[t]ikv-server' | grep 20160
#
# Kill by explicit PID, never with `pkill -f` — during this project a
# `pkill -f` pattern matched the invoking shell's own command line.
set -euo pipefail

case "${1:-}" in
  kill)
    : "${STORE1_PID:?set STORE1_PID to the pid of TiKV store 1 first (see header)}"
    kill -9 "$STORE1_PID"
    echo "TiKV store 1 killed."
    echo "Now screenshot the Dashboard while it is down:"
    echo "  http://127.0.0.1:2379/dashboard -> Cluster Info -> Instances"
    echo "  -> results/screenshots/exp9_tidb_down.png"
    echo "Expect: 127.0.0.1:20160 Unreachable; stores 2/3 and TiFlash still Up."
    ;;

  verify)
    # TiUP's playground supervises the store and brings it back in place;
    # this confirms when it has actually returned.
    mariadb -h 127.0.0.1 -P 4000 -u root -e \
      "SELECT store_id, address, store_state_name FROM information_schema.tikv_store_status;"
    echo
    echo "Expect store 1 back to Up."
    ;;

  *)
    echo "usage: STORE1_PID=<pid> bash $0 kill   |   bash $0 verify" >&2
    exit 2
    ;;
esac
