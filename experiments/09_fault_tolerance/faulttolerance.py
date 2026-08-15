#!/usr/bin/env python3
"""
Experiment 9 — fault tolerance under a node failure.

Runs a continuous, single-threaded transfer loop (debit account 1, credit
account 2, alternating direction) against a running engine, logging every
transaction's outcome, latency, and wall-clock elapsed time. This script
does NOT kill or restart any node itself -- that is a deliberate manual
step the operator performs in a separate terminal, at the moments this
script announces, so the actual kill/restart commands stay in the
operator's own shell history rather than being run silently.

Default protocol (per the runbook), 300s total:
  T+0s   .. T+60s   baseline, no node down
  T+60s  .. T+180s  a storage node/store is down -- elevated errors expected
  T+180s .. T+300s  recovery, after the node has been restarted

On any failure the script closes and reopens its connection before the
next attempt, mirroring how a real client recovers from a dropped node.

Usage:
    source .venv/bin/activate
    python3 experiments/09_fault_tolerance/faulttolerance.py --engine crdb
    python3 experiments/09_fault_tolerance/faulttolerance.py --engine tidb
"""
import argparse
import csv
import os
import time

import mysql.connector
import psycopg2
from google.cloud import spanner
from google.cloud.spanner_v1 import param_types

CSV_PATH_TEMPLATE = "experiments/09_fault_tolerance/exp9_{engine}_faulttolerance.csv"
TOTAL_DURATION_SEC = 300
KILL_AT_SEC = 60
RESTART_AT_SEC = 180
RECONNECT_BACKOFF_SEC = 0.5
SPANNER_EMULATOR_HOST_DEFAULT = "localhost:30010"
SPANNER_DATABASE_NAME = "seminar-multiserver"


def crdb_connect():
    connection = psycopg2.connect(
        host="localhost", port=26257, user="root", dbname="seminar",
        sslmode="disable", connect_timeout=5,
    )
    connection.autocommit = True
    return connection


def tidb_connect():
    connection = mysql.connector.connect(
        host="127.0.0.1", port=4000, user="root", password="", database="seminar",
        connection_timeout=5,
    )
    connection.autocommit = True
    return connection


def spanner_connect():
    # Points at the 3-root-server multi-server deployment (Phase 3/4 of
    # docs/spanner_multiserver_setup.md), not the single-server `spanneromni`
    # container -- this experiment needs RF=3 to have a node worth killing.
    os.environ["SPANNER_EMULATOR_HOST"] = SPANNER_EMULATOR_HOST_DEFAULT
    client = spanner.Client(project="test-project")
    instance = client.instance("test-instance")
    return instance.database(SPANNER_DATABASE_NAME)


def connect(engine):
    if engine == "crdb":
        return crdb_connect()
    elif engine == "tidb":
        return tidb_connect()
    else:
        return spanner_connect()


def run_transfer(connection, direction, engine):
    debit_account_id, credit_account_id = (1, 2) if direction == 0 else (2, 1)

    if engine == "spanner":
        def transaction_callback(transaction):
            transaction.execute_update(
                "UPDATE accounts SET balance = balance - 1 WHERE id = @id",
                params={"id": debit_account_id}, param_types={"id": param_types.INT64},
            )
            transaction.execute_update(
                "UPDATE accounts SET balance = balance + 1 WHERE id = @id",
                params={"id": credit_account_id}, param_types={"id": param_types.INT64},
            )
        connection.run_in_transaction(transaction_callback)
        return

    cursor = connection.cursor()
    cursor.execute("BEGIN;")
    cursor.execute("UPDATE accounts SET balance = balance - 1 WHERE id = %s", (debit_account_id,))
    cursor.execute("UPDATE accounts SET balance = balance + 1 WHERE id = %s", (credit_account_id,))
    cursor.execute("COMMIT;")


def main():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("--engine", required=True, choices=["crdb", "tidb", "spanner"])
    arg_parser.add_argument("--duration", type=int, default=TOTAL_DURATION_SEC)
    arg_parser.add_argument("--kill-at", type=int, default=KILL_AT_SEC)
    arg_parser.add_argument("--restart-at", type=int, default=RESTART_AT_SEC)
    args = arg_parser.parse_args()

    csv_path = CSV_PATH_TEMPLATE.format(engine=args.engine)
    write_header = not os.path.exists(csv_path)

    connection = connect(args.engine)
    txn_index = 0
    kill_announced = False
    restart_announced = False
    start_time = time.perf_counter()

    with open(csv_path, "a", newline="") as csv_file:
        writer = csv.writer(csv_file)
        if write_header:
            writer.writerow(["engine", "elapsed_s", "txn_index", "success", "latency_ms", "error_message"])

        while True:
            elapsed_s = time.perf_counter() - start_time
            if elapsed_s >= args.duration:
                break

            if not kill_announced and elapsed_s >= args.kill_at:
                kill_announced = True
                print(f"\n*** T+{args.kill_at}s: KILL A NODE NOW (see the other terminal for the command) ***\n")
            if not restart_announced and elapsed_s >= args.restart_at:
                restart_announced = True
                print(f"\n*** T+{args.restart_at}s: RESTART THE NODE NOW (see the other terminal for the command) ***\n")

            txn_index += 1
            direction = txn_index % 2
            op_start = time.perf_counter()
            try:
                run_transfer(connection, direction, args.engine)
                latency_ms = (time.perf_counter() - op_start) * 1000
                writer.writerow([args.engine, f"{elapsed_s:.2f}", txn_index, 1, f"{latency_ms:.3f}", ""])
                if txn_index % 20 == 0:
                    print(f"T+{elapsed_s:.0f}s txn {txn_index}: OK {latency_ms:.1f}ms")
            except Exception as error:
                latency_ms = (time.perf_counter() - op_start) * 1000
                error_message = str(error).replace("\n", " ")[:200]
                writer.writerow([args.engine, f"{elapsed_s:.2f}", txn_index, 0, f"{latency_ms:.3f}", error_message])
                print(f"T+{elapsed_s:.0f}s txn {txn_index}: FAIL {latency_ms:.1f}ms - {error_message}")
                try:
                    connection.close()
                except Exception:
                    pass
                time.sleep(RECONNECT_BACKOFF_SEC)
                try:
                    connection = connect(args.engine)
                except Exception as reconnect_error:
                    print(f"  reconnect failed: {reconnect_error}")
            csv_file.flush()

    print(f"Done. Appended to {csv_path}")


if __name__ == "__main__":
    main()
