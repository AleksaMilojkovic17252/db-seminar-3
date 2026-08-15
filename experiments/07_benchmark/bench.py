#!/usr/bin/env python3
"""
Experiment 7 — indicative performance characteristics.

Reframed per the runbook's R3: this is NOT a head-to-head benchmark. It
characterizes each engine's own response to rising concurrency, run one
engine at a time with the other two stopped/idle (record which in
results/env.txt). Any chart built from this data must use separate panels
per engine, not a single shared axis.

Workload mix, all against `accounts` (50,000 rows):
    point_read  — SELECT balance FROM accounts WHERE id = <random>
    point_write — UPDATE accounts SET balance = balance + 1 WHERE id = <random>
    transfer    — BEGIN; debit one random account, credit another; COMMIT

Concurrency sweep: 1, 4, 16, 32, 64 threads, one connection per worker
thread, fixed 30s measurement window per level, 3 repetitions per level.
Each worker does a small unmeasured warm-up before its timed window.
Conflicts that raise a serialization/deadlock error are retried in place;
the retry count is logged as its own metric, not hidden inside latency.

Deviation from "one connection per worker" for Spanner only: the
google-cloud-spanner client manages its own internal session pool on a
shared Database object, which is the correct/thread-safe usage pattern
for that client library — reconnecting per-thread would fight the
library's own pooling rather than test anything meaningful.

Usage:
    source .venv/bin/activate
    python3 experiments/07_benchmark/bench.py --engine crdb         --conns 1,4,16,32,64 --duration 30 --reps 3
    python3 experiments/07_benchmark/bench.py --engine tidb         --conns 1,4,16,32,64 --duration 30 --reps 3
    python3 experiments/07_benchmark/bench.py --engine spanner      --conns 1,4,16,32,64 --duration 30 --reps 3
    python3 experiments/07_benchmark/bench.py --engine spanner_multi --conns 1,4,16,32,64 --duration 30 --reps 3  # RF=3 redo

    # quick smoke test before committing to the full sweep:
    python3 experiments/07_benchmark/bench.py --engine crdb --conns 1,4 --duration 3 --reps 1
"""
import argparse
import csv
import os
import random
import threading
import time

import mysql.connector
import psycopg2
import psycopg2.errors
from google.cloud import spanner
from google.cloud.spanner_v1 import param_types

N_ACCOUNTS = 50_000
CONCURRENCY_LEVELS = [1, 4, 16, 32, 64]
DURATION_SEC = 30
N_REPS = 3
N_WARMUP_OPS = 3
WORKLOADS = ["point_read", "point_write", "transfer"]
CSV_PATH = "experiments/07_benchmark/bench_results.csv"

_spanner_database = None
_spanner_multi_database = None


def compute_percentile(values, percentile):
    if not values:
        return float("nan")
    sorted_values = sorted(values)
    rank = (len(sorted_values) - 1) * percentile
    lower_idx = int(rank)
    upper_idx = min(lower_idx + 1, len(sorted_values) - 1)
    if lower_idx == upper_idx:
        return sorted_values[lower_idx]
    return sorted_values[lower_idx] + (sorted_values[upper_idx] - sorted_values[lower_idx]) * (rank - lower_idx)


def pick_two_distinct_account_ids(random_generator):
    debit_account_id = random_generator.randint(1, N_ACCOUNTS)
    credit_account_id = random_generator.randint(1, N_ACCOUNTS)
    if debit_account_id == credit_account_id:
        credit_account_id = debit_account_id % N_ACCOUNTS + 1
    return debit_account_id, credit_account_id


# --- CockroachDB ---

def crdb_connect():
    connection = psycopg2.connect(host="localhost", port=26257, user="root", dbname="seminar", sslmode="disable")
    connection.autocommit = True
    return connection


def crdb_op(connection, workload, random_generator):
    cursor = connection.cursor()
    retry_count = 0
    while True:
        try:
            if workload == "point_read":
                account_id = random_generator.randint(1, N_ACCOUNTS)
                cursor.execute("SELECT balance FROM accounts WHERE id = %s", (account_id,))
                cursor.fetchone()
            elif workload == "point_write":
                account_id = random_generator.randint(1, N_ACCOUNTS)
                cursor.execute("UPDATE accounts SET balance = balance + 1 WHERE id = %s", (account_id,))
            else:
                debit_account_id, credit_account_id = pick_two_distinct_account_ids(random_generator)
                cursor.execute("BEGIN;")
                cursor.execute("UPDATE accounts SET balance = balance - 1 WHERE id = %s", (debit_account_id,))
                cursor.execute("UPDATE accounts SET balance = balance + 1 WHERE id = %s", (credit_account_id,))
                cursor.execute("COMMIT;")
            return retry_count
        except psycopg2.errors.SerializationFailure:
            connection.rollback()
            retry_count += 1


# --- TiDB ---

def tidb_connect():
    connection = mysql.connector.connect(host="127.0.0.1", port=4000, user="root", password="", database="seminar")
    connection.autocommit = True
    return connection


def tidb_op(connection, workload, random_generator):
    cursor = connection.cursor()
    retry_count = 0
    while True:
        try:
            if workload == "point_read":
                account_id = random_generator.randint(1, N_ACCOUNTS)
                cursor.execute("SELECT balance FROM accounts WHERE id = %s", (account_id,))
                cursor.fetchone()
            elif workload == "point_write":
                account_id = random_generator.randint(1, N_ACCOUNTS)
                cursor.execute("UPDATE accounts SET balance = balance + 1 WHERE id = %s", (account_id,))
            else:
                debit_account_id, credit_account_id = pick_two_distinct_account_ids(random_generator)
                cursor.execute("BEGIN;")
                cursor.execute("UPDATE accounts SET balance = balance - 1 WHERE id = %s", (debit_account_id,))
                cursor.execute("UPDATE accounts SET balance = balance + 1 WHERE id = %s", (credit_account_id,))
                cursor.execute("COMMIT;")
            return retry_count
        except mysql.connector.errors.DatabaseError as error:
            error_message = str(error).lower()
            if "deadlock" in error_message or "conflict" in error_message or getattr(error, "errno", None) == 1213:
                connection.rollback()
                retry_count += 1
                continue
            raise


# --- Spanner Omni ---

def spanner_connect():
    # Original single-server (RF=1) deployment -- port 15000, database `seminar`.
    global _spanner_database
    if _spanner_database is None:
        os.environ["SPANNER_EMULATOR_HOST"] = "localhost:15000"
        client = spanner.Client(project="test-project")
        instance = client.instance("test-instance")
        _spanner_database = instance.database("seminar")
    return _spanner_database


def spanner_multi_connect():
    # Multi-server (RF=3-equivalent) deployment on local k3s -- see
    # docs/spanner_multiserver_setup.md. Separate engine label and separate
    # cached Database object so the original RF=1 rows in bench_results.csv
    # (engine="spanner") stay untouched and both remain independently
    # queryable/chartable.
    global _spanner_multi_database
    if _spanner_multi_database is None:
        os.environ["SPANNER_EMULATOR_HOST"] = "localhost:30010"
        client = spanner.Client(project="test-project")
        instance = client.instance("test-instance")
        _spanner_multi_database = instance.database("seminar-multiserver")
    return _spanner_multi_database


def spanner_op(database, workload, random_generator):
    if workload == "point_read":
        account_id = random_generator.randint(1, N_ACCOUNTS)
        with database.snapshot() as snapshot:
            list(snapshot.execute_sql(
                "SELECT balance FROM accounts WHERE id = @id",
                params={"id": account_id}, param_types={"id": param_types.INT64},
            ))
        return 0

    attempt_counter = [0]

    if workload == "point_write":
        account_id = random_generator.randint(1, N_ACCOUNTS)

        def transaction_callback(transaction):
            attempt_counter[0] += 1
            transaction.execute_update(
                "UPDATE accounts SET balance = balance + 1 WHERE id = @id",
                params={"id": account_id}, param_types={"id": param_types.INT64},
            )
    else:
        debit_account_id, credit_account_id = pick_two_distinct_account_ids(random_generator)

        def transaction_callback(transaction):
            attempt_counter[0] += 1
            transaction.execute_update(
                "UPDATE accounts SET balance = balance - 1 WHERE id = @id",
                params={"id": debit_account_id}, param_types={"id": param_types.INT64},
            )
            transaction.execute_update(
                "UPDATE accounts SET balance = balance + 1 WHERE id = @id",
                params={"id": credit_account_id}, param_types={"id": param_types.INT64},
            )

    database.run_in_transaction(transaction_callback)
    return attempt_counter[0] - 1


def run_op(engine, connection, workload, random_generator):
    if engine == "crdb":
        return crdb_op(connection, workload, random_generator)
    elif engine == "tidb":
        return tidb_op(connection, workload, random_generator)
    else:
        return spanner_op(connection, workload, random_generator)


def worker(engine, workload, duration_sec, results_by_worker, worker_index):
    random_generator = random.Random((worker_index + 1) * 7919 + int(time.time() * 1000))

    if engine == "crdb":
        connection = crdb_connect()
    elif engine == "tidb":
        connection = tidb_connect()
    elif engine == "spanner":
        connection = spanner_connect()
    else:
        connection = spanner_multi_connect()

    for _ in range(N_WARMUP_OPS):
        run_op(engine, connection, workload, random_generator)

    latencies_ms = []
    retry_count_total = 0
    deadline = time.perf_counter() + duration_sec
    while time.perf_counter() < deadline:
        op_start = time.perf_counter()
        retry_count_total += run_op(engine, connection, workload, random_generator)
        latencies_ms.append((time.perf_counter() - op_start) * 1000)

    if engine in ("crdb", "tidb"):
        connection.close()

    results_by_worker[worker_index] = (latencies_ms, retry_count_total)


def main():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("--engine", required=True, choices=["crdb", "tidb", "spanner", "spanner_multi"])
    arg_parser.add_argument("--conns", default=",".join(str(c) for c in CONCURRENCY_LEVELS))
    arg_parser.add_argument("--duration", type=int, default=DURATION_SEC)
    arg_parser.add_argument("--reps", type=int, default=N_REPS)
    arg_parser.add_argument("--workloads", default=",".join(WORKLOADS))
    arg_parser.add_argument("--csv-path", default=CSV_PATH)
    args = arg_parser.parse_args()

    concurrency_levels = [int(c) for c in args.conns.split(",")]
    workloads = args.workloads.split(",")

    write_header = not os.path.exists(args.csv_path)
    with open(args.csv_path, "a", newline="") as csv_file:
        writer = csv.writer(csv_file)
        if write_header:
            writer.writerow(["engine", "workload", "concurrency", "rep", "ops_per_sec", "p50", "p95", "p99", "retries"])

        for workload in workloads:
            for concurrency in concurrency_levels:
                for rep in range(1, args.reps + 1):
                    print(f"[{args.engine}] {workload} conc={concurrency} rep={rep}/{args.reps}")
                    results_by_worker = [None] * concurrency
                    threads = [
                        threading.Thread(target=worker, args=(args.engine, workload, args.duration, results_by_worker, worker_index))
                        for worker_index in range(concurrency)
                    ]
                    for thread in threads:
                        thread.start()
                    for thread in threads:
                        thread.join()

                    all_latencies_ms = []
                    retry_count_total = 0
                    for worker_latencies_ms, worker_retry_count in results_by_worker:
                        all_latencies_ms.extend(worker_latencies_ms)
                        retry_count_total += worker_retry_count

                    ops_per_sec = len(all_latencies_ms) / args.duration
                    p50 = compute_percentile(all_latencies_ms, 0.50)
                    p95 = compute_percentile(all_latencies_ms, 0.95)
                    p99 = compute_percentile(all_latencies_ms, 0.99)
                    writer.writerow([args.engine, workload, concurrency, rep,
                                      f"{ops_per_sec:.2f}", f"{p50:.3f}", f"{p95:.3f}", f"{p99:.3f}", retry_count_total])
                    csv_file.flush()
                    print(f"  ops/sec={ops_per_sec:.1f} p50={p50:.2f}ms p95={p95:.2f}ms p99={p99:.2f}ms retries={retry_count_total}")

    print(f"Done. Appended to {args.csv_path}")


if __name__ == "__main__":
    main()
