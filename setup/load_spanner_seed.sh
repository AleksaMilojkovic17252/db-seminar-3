#!/usr/bin/env bash
set -e
# Spanner's `execute-sql` CLI takes exactly one --sql statement per
# invocation (no bulk-file loading), so this feeds schema/seed_spanner.sql
# to the CLI one line (= one ~1000-row batch) at a time.
SEED_FILE="schema/seed_spanner.sql"
TOTAL=$(wc -l < "$SEED_FILE")
N=0
while IFS= read -r stmt; do
  N=$((N+1))
  echo "[$N/$TOTAL] ${stmt:0:60}..."
  docker exec spanneromni /google/spanner/bin/spanner \
    databases execute-sql seminar --sql="$stmt" > /dev/null
done < "$SEED_FILE"
echo "Done."
