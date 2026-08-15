#!/usr/bin/env bash
# Stops all three engines for this project. Data persists on disk / in the
# named Docker volume, so this is safe to run at the end of any session --
# `setup/start_tidb.sh`, `setup/start_crdb.sh`, and `docker start spanneromni`
# resume everything next time (see docs/daily_startup.md).

echo "Stopping TiDB (pd/tikv/tidb-server/tiflash/grafana/prometheus)..."
pkill -f 'tiup playground' 2>/dev/null
pkill -f 'pd-server' 2>/dev/null
pkill -f 'tikv-server' 2>/dev/null
pkill -f 'tidb-server' 2>/dev/null
pkill -f 'TiFlashMain' 2>/dev/null
pkill -f 'grafana-server' 2>/dev/null
pkill -f 'prometheus' 2>/dev/null

echo "Stopping CockroachDB (3 nodes, graceful drain -- can take up to ~15s)..."
pkill -f 'cockroachdb-26' 2>/dev/null
for i in $(seq 1 15); do
  pgrep -f 'cockroachdb-26' >/dev/null 2>&1 || break
  sleep 1
done
if pgrep -f 'cockroachdb-26' >/dev/null 2>&1; then
  echo "  still up after graceful wait -- force killing"
  pkill -9 -f 'cockroachdb-26' 2>/dev/null
  sleep 1
fi

echo "Stopping Spanner Omni container..."
docker stop spanneromni >/dev/null 2>&1

echo "Stopping Spanner Omni multi-server deployment (k3s)..."
systemctl is-active --quiet k3s && sudo systemctl stop k3s

sleep 2

echo ""
echo "=== Verification ==="
if pgrep -af 'tiup playground|pd-server|tikv-server|tidb-server|TiFlashMain' >/dev/null 2>&1; then
  echo "TiDB: still running -- $(pgrep -af 'tiup playground|pd-server|tikv-server|tidb-server|TiFlashMain' | wc -l) process(es) left"
else
  echo "TiDB: stopped"
fi

if pgrep -af 'cockroachdb-26' >/dev/null 2>&1; then
  echo "CockroachDB: still running (force-kill also failed -- check manually with 'pgrep -af cockroachdb-26')"
else
  echo "CockroachDB: stopped"
fi

echo "Spanner Omni (single-server): $(docker ps -a --filter name=spanneromni --format '{{.Status}}')"

echo "Spanner Omni (multi-server/k3s): $(systemctl is-active k3s)"
