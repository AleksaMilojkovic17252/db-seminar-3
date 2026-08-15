#!/usr/bin/env bash
# Experiment 6 — Spanner Omni — attempt to go from 3 to 4 ROOT servers.
# Run: bash 02_attempt_4_root.sh
#
# THIS IS EXPECTED TO FAIL. The failure is the finding: root servers form a
# Paxos voting group and the chart validates that their count is odd.
# Nothing is created; the upgrade is rejected before touching the cluster.
set -euo pipefail

helm upgrade spanner-omni \
  oci://us-docker.pkg.dev/spanner-omni/charts/spanner-omni --version 0.2.0 \
  --namespace spanner-ns \
  --reuse-values \
  --set deployment.replicasPerZone=4 \
  --set deployment.rootServersPerZone=4

# Expected output:
#   Error: UPGRADE FAILED: execution error at
#   (spanner-omni/templates/validations.yaml:37:10):
#   [FATAL] Zone 'local-a' in location 'local' has '4' root servers configured.
#   The number of root servers must be an odd number between 1 and 9
#   (i.e. 1, 3, 5, 7, or 9)!
