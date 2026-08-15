#!/usr/bin/env bash
# Experiment 6 — Spanner Omni — remove the 4th server, return to clean 3
# Run: bash 05_cleanup.sh
#
# RUN THIS BEFORE EXPERIMENT 9. Helm's scale-down removes the pod but does
# NOT deregister the server from Spanner's own internal directory. Leaving
# the stale registration behind caused two unexplained 1-2s latency blips
# in the first fault-tolerance run.
set -euo pipefail

helm upgrade spanner-omni \
  oci://us-docker.pkg.dev/spanner-omni/charts/spanner-omni --version 0.2.0 \
  --namespace spanner-ns \
  --reuse-values \
  --set deployment.replicasPerZone=3 \
  --set deployment.rootServersPerZone=3

# Helm leaves the PVC behind as well.
kubectl delete pvc -n spanner-ns -l 'app.kubernetes.io/instance=spanner-omni' \
  --field-selector 'metadata.name!=' 2>/dev/null || true

echo
echo "## Deregister the stale server entry (the step Helm does not do)"
kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner \
  deployment servers delete spanner-a-3.pod.spanner-ns:15000 --zone=local-a --quiet

echo
echo "## Confirm 3 servers, all root, all READY"
kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner \
  deployment servers list --zone local-a
