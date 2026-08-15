#!/usr/bin/env bash
set -e
SEED_FILE="schema/seed_spanner.sql"
TOTAL=$(wc -l < "$SEED_FILE")
N=0
while IFS= read -r stmt; do
  N=$((N+1))
  echo "[$N/$TOTAL] ${stmt:0:60}..."
  kubectl exec spanner-a-0 -n spanner-ns -- \
    /google/spanner/bin/spanner databases execute-sql seminar-multiserver --sql="$stmt" > /dev/null
done < "$SEED_FILE"
echo "Done."
