#!/usr/bin/env bash
# Experiment 6 — Spanner Omni — add a 4th server as NON-ROOT
# Run: bash 03_add_nonroot.sh   (after 02_attempt_4_root.sh has failed)
#
# replicasPerZone goes to 4; rootServersPerZone stays at 3, keeping the
# voting group odd. This is accepted, and the existing 3 pods are NOT
# restarted.
set -euo pipefail

helm upgrade spanner-omni \
  oci://us-docker.pkg.dev/spanner-omni/charts/spanner-omni --version 0.2.0 \
  --namespace spanner-ns \
  --reuse-values \
  --set deployment.replicasPerZone=4 \
  --set deployment.rootServersPerZone=3

echo
echo "## Confirm the existing 3 pods were NOT restarted — check AGE and RESTARTS"
kubectl get pods -n spanner-ns
