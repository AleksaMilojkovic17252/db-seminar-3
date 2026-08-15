#!/usr/bin/env bash
# Starts (or verifies) the multi-server (RF=3-equivalent) Spanner Omni
# deployment on local k3s. Pods are managed by k3s/the StatefulSet, not by
# this script -- as long as the k3s systemd service is up, they come back
# on their own. This just makes sure of that and reports connection info.
# Full setup record: docs/spanner_multiserver_setup.md
set -e

echo "Ensuring k3s is running..."
systemctl is-active --quiet k3s || sudo systemctl start k3s
export KUBECONFIG="$HOME/.kube/config"

echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready node --all --timeout=60s

echo "Waiting for Spanner pods..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=spanner -n spanner-ns --timeout=180s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=console -n spanner-ns --timeout=180s || true

echo ""
echo "=== Pods ==="
kubectl get pods -n spanner-ns

echo ""
echo "=== Connection info ==="
echo "gRPC endpoint:  localhost:30010  (database: seminar-multiserver)"
echo "Console UI:     http://localhost:30026"
