#!/usr/bin/env bash
# Experiment 8 — Spanner Omni — full-text search on the bundled sample DB
# Run: bash 03_fulltext.sh
#
# retail-sample is created with:
#   docker exec -it spanneromni /google/spanner/bin/spanner \
#     databases create-sample-db retail --database-name=retail-sample
set -euo pipefail

docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql retail-sample \
  --sql="SELECT ProductID, Name FROM Products WHERE SEARCH(Name_Tokens, 'phone') LIMIT 10"
