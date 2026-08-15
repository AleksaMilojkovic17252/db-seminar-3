#!/usr/bin/env python3
"""
Experiment 3 — transaction commit latency benchmark.

3 independent runs of 200 transactions each (per the runbook's measurement
protocol), one engine at a time. Each transaction is a 2-row transfer:
debit account 1 / credit account 2, alternating direction every other
transaction so balances stay roughly stable across repeated runs. Records
median/p95/p99 are computed downstream from the raw per-transaction CSV,
not here -- this script's only job is to log every individual latency.

Run ONE engine at a time, with the other two stopped/idle (per the runbook;
record which in results/env.txt). Between runs, the script itself sleeps
30s.

Usage:
    source .venv/bin/activate
    python3 experiments/03_transactions/bench_transactions.py --engine crdb
    python3 experiments/03_transactions/bench_transactions.py --engine tidb
    python3 experiments/03_transactions/bench_transactions.py --engine spanner
    python3 experiments/03_transactions/bench_transactions.py --engine spanner_multi  # RF=3 redo, see docs/spanner_multiserver_setup.md
"""
import argparse
import csv
import os
import time

import mysql.connector
import psycopg2
from google.cloud import spanner

N_TXNS = 200
N_RUNS = 3
IDLE_BETWEEN_RUNS_SEC = 30
CSV_PATH = "experiments/03_transactions/exp3_latency.csv"


def bench_crdb():
    conn = psycopg2.connect(host="localhost", port=26257, user="root", dbname="seminar", sslmode="disable")
    conn.autocommit = True
    cur = conn.cursor()

    def run_txn(direction):
        t0 = time.perf_counter()
        cur.execute("BEGIN;")
        if direction == 0:
            cur.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1;")
            cur.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2;")
        else:
            cur.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 2;")
            cur.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 1;")
        cur.execute("COMMIT;")
        return (time.perf_counter() - t0) * 1000

    return run_txn, conn


def bench_tidb():
    conn = mysql.connector.connect(host="127.0.0.1", port=4000, user="root", password="", database="seminar")
    conn.autocommit = True
    cur = conn.cursor()

    def run_txn(direction):
        t0 = time.perf_counter()
        cur.execute("BEGIN;")
        if direction == 0:
            cur.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1;")
            cur.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2;")
        else:
            cur.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 2;")
            cur.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 1;")
        cur.execute("COMMIT;")
        return (time.perf_counter() - t0) * 1000

    return run_txn, conn


def _bench_spanner_common(emulator_host, database_name):
    os.environ["SPANNER_EMULATOR_HOST"] = emulator_host
    client = spanner.Client(project="test-project")
    instance = client.instance("test-instance")
    database = instance.database(database_name)

    def run_txn(direction):
        def transfer(transaction):
            if direction == 0:
                transaction.execute_update("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
                transaction.execute_update("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
            else:
                transaction.execute_update("UPDATE accounts SET balance = balance - 100 WHERE id = 2")
                transaction.execute_update("UPDATE accounts SET balance = balance + 100 WHERE id = 1")

        t0 = time.perf_counter()
        database.run_in_transaction(transfer)
        return (time.perf_counter() - t0) * 1000

    return run_txn, database


def bench_spanner():
    # Original single-server (RF=1) deployment -- port 15000, database `seminar`.
    return _bench_spanner_common("localhost:15000", "seminar")


def bench_spanner_multi():
    # Multi-server (RF=3-equivalent) deployment on local k3s -- see
    # docs/spanner_multiserver_setup.md. Kept as a SEPARATE engine label
    # (not overwriting "spanner") so the original RF=1 rows in
    # exp3_latency.csv stay intact and both remain independently queryable.
    return _bench_spanner_common("localhost:30010", "seminar-multiserver")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", required=True, choices=["crdb", "tidb", "spanner", "spanner_multi"])
    ap.add_argument("--runs", type=int, default=N_RUNS)
    ap.add_argument("--n", type=int, default=N_TXNS)
    args = ap.parse_args()

    if args.engine == "crdb":
        run_txn, _conn = bench_crdb()
    elif args.engine == "tidb":
        run_txn, _conn = bench_tidb()
    elif args.engine == "spanner":
        run_txn, _conn = bench_spanner()
    else:
        run_txn, _conn = bench_spanner_multi()

    write_header = not os.path.exists(CSV_PATH)
    with open(CSV_PATH, "a", newline="") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(["engine", "run", "txn_index", "latency_ms"])

        for run in range(1, args.runs + 1):
            print(f"[{args.engine}] run {run}/{args.runs}")
            for i in range(args.n):
                latency_ms = run_txn(i % 2)
                writer.writerow([args.engine, run, i, f"{latency_ms:.3f}"])
                if (i + 1) % 50 == 0:
                    print(f"  {i + 1}/{args.n}")
            f.flush()
            if run < args.runs:
                print(f"  idling {IDLE_BETWEEN_RUNS_SEC}s before next run...")
                time.sleep(IDLE_BETWEEN_RUNS_SEC)

    print(f"Done. Appended to {CSV_PATH}")


if __name__ == "__main__":
    main()
