#!/usr/bin/env bash
set -e
JOIN=localhost:26257,localhost:26258,localhost:26259
LOCALITIES=(region=eu-west,zone=a region=us-east,zone=b region=us-west,zone=c)
for i in 1 2 3; do
  SQL=$((26256+i)); HTTP=$((8079+i))
  nohup cockroachdb-26 start --insecure --store=node$i \
    --listen-addr=localhost:$SQL --advertise-addr=localhost:$SQL \
    --http-addr=localhost:$HTTP --join=$JOIN \
    --locality="${LOCALITIES[$((i-1))]}" \
    > node$i.log 2>&1 &
done
sleep 5
cockroachdb-26 init --insecure --host=localhost:26257 || true
