#!/usr/bin/env bash
set -e
# --tag pins the data directory. This exact tag (VQajpo8) is what the
# original cluster's schema/data was written under — reusing it resumes
# the same cluster instead of bootstrapping an empty one. Runs in the
# foreground; leave this terminal open, or Ctrl+C to stop the cluster.
tiup playground v8.5.7 --db 1 --pd 1 --kv 3 --tiflash 1 --host 127.0.0.1 --tag VQajpo8
