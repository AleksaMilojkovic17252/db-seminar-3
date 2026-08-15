#!/usr/bin/env bash
set -e
docker volume create spanner
docker run -d --network host --name spanneromni \
  -v "spanner:/spanner" \
  us-docker.pkg.dev/spanner-omni/images/spanner-omni:2026.r1-beta.2 start-single-server
sleep 10
# Deviation from runbook: in 2026.r1-beta.2, start-single-server does NOT
# launch the console automatically. It must be started as a separate
# in-container process, or the console (port 15026) never comes up.
docker exec -d spanneromni /app/bin/spanner-console
sleep 8
docker exec -i spanneromni /google/spanner/bin/spanner \
  databases create-sample-db retail --database-name=retail-sample
