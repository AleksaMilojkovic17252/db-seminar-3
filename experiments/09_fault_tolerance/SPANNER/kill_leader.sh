#!/usr/bin/env bash
# Experiment 9 — Spanner Omni — kill the Paxos leader at T+60s
# Run in a SECOND terminal, at the moment run.sh announces.
#
# There is NO restart step. Kubernetes reschedules the pod on its own
# schedule; the experiment observes that rather than triggering it.
set -euo pipefail

# Confirm who leads the user-data group before killing anything —
# killing a follower would test far less than killing the leader.
kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner \
  admin alpha descriptor print seminar-multiserver 51380225

# ---- At T+60s ----
kubectl delete pod spanner-a-1 -n spanner-ns --grace-period=0 --force

# ---- Watch it come back on its own ----
kubectl get pods -n spanner-ns -w

# ---- After the run ----
kubectl exec spanner-a-0 -n spanner-ns -- /google/spanner/bin/spanner \
  deployment servers list --zone local-a
# Expect: all 3 root servers READY again.
