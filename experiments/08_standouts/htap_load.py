#!/usr/bin/env python3
"""
Experiment 8 — TiDB HTAP isolation demo: OLAP load generator.

Loops the TiFlash-routed category-aggregation query against TiDB
continuously, so it can run in one terminal while
experiments/07_benchmark/bench.py measures OLTP (point_read/point_write)
latency against the same cluster in another terminal. The comparison that
matters is OLTP p99 WITH this running vs. WITHOUT it — that isolation
between the OLAP and OLTP paths is the actual HTAP claim, not the
mpp[tiflash] plan by itself.

Usage:
    source .venv/bin/activate
    python3 experiments/08_standouts/htap_load.py --duration 60
"""
import argparse
import time

import mysql.connector

HTAP_QUERY = """
SELECT p.category, SUM(oi.quantity * oi.unit_price) AS total_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
GROUP BY p.category
"""


def main():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("--duration", type=int, default=60)
    args = arg_parser.parse_args()

    connection = mysql.connector.connect(host="127.0.0.1", port=4000, user="root", password="", database="seminar")
    connection.autocommit = True
    cursor = connection.cursor()

    query_count = 0
    deadline = time.perf_counter() + args.duration
    while time.perf_counter() < deadline:
        query_start = time.perf_counter()
        cursor.execute(HTAP_QUERY)
        cursor.fetchall()
        query_count += 1
        print(f"HTAP query {query_count}: {(time.perf_counter() - query_start) * 1000:.1f}ms")

    connection.close()
    print(f"Done. Ran {query_count} HTAP queries over {args.duration}s.")


if __name__ == "__main__":
    main()
