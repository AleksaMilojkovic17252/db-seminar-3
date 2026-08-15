#!/usr/bin/env python3
"""
Experiment 9 — chart generation from exp9_<engine>_faulttolerance.csv.

Two-panel figure per engine: latency over time (rolling-window p50/p99)
on top, error count over time on the bottom, both with vertical markers
at the kill and restart timestamps. One chart per engine — not panelled
side-by-side like Experiment 7's charts, since this experiment is
explicitly a per-engine timeline, not a cross-engine comparison (R1: only
CockroachDB and TiDB ran this experiment; Spanner is single-server and
excluded).

Usage:
    source .venv/bin/activate
    python3 experiments/09_fault_tolerance/make_charts.py --engine crdb
    python3 experiments/09_fault_tolerance/make_charts.py --engine tidb
"""
import argparse
import csv
from collections import defaultdict

import matplotlib.pyplot as plt

CSV_PATH_TEMPLATE = "experiments/09_fault_tolerance/exp9_{engine}_faulttolerance.csv"
OUTPUT_PATH_TEMPLATE = "results/benchmark_charts/exp9_{engine}_timeline.png"
ENGINE_LABELS = {"crdb": "CockroachDB", "tidb": "TiDB", "spanner": "Spanner Omni"}
KILL_AT_SEC = 60
RESTART_AT_SEC = 180
WINDOW_SEC = 5

CHART_SURFACE = "#fcfcfb"
GRID_COLOR = "#e1e0d9"
AXIS_COLOR = "#c3c2b7"
MUTED_INK = "#898781"
PRIMARY_INK = "#0b0b0b"
LATENCY_COLOR = "#2a78d6"
P99_COLOR = "#eb6834"
ERROR_COLOR = "#e34948"
MARKER_COLOR = "#52514e"


def load_rows(csv_path):
    rows = []
    with open(csv_path) as csv_file:
        for row in csv.DictReader(csv_file):
            rows.append({
                "elapsed_s": float(row["elapsed_s"]),
                "success": int(row["success"]),
                "latency_ms": float(row["latency_ms"]),
            })
    return rows


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


def bucket_rows(rows, total_duration):
    buckets = defaultdict(list)
    for row in rows:
        bucket_index = int(row["elapsed_s"] // WINDOW_SEC)
        buckets[bucket_index].append(row)

    bucket_starts, p50s, p99s, error_counts = [], [], [], []
    for bucket_index in range(0, int(total_duration // WINDOW_SEC) + 1):
        bucket = buckets.get(bucket_index, [])
        bucket_starts.append(bucket_index * WINDOW_SEC)
        successful_latencies = [r["latency_ms"] for r in bucket if r["success"] == 1]
        p50s.append(compute_percentile(successful_latencies, 0.50) if successful_latencies else None)
        p99s.append(compute_percentile(successful_latencies, 0.99) if successful_latencies else None)
        error_counts.append(sum(1 for r in bucket if r["success"] == 0))
    return bucket_starts, p50s, p99s, error_counts


def style_panel_axis(ax):
    ax.set_facecolor(CHART_SURFACE)
    ax.set_axisbelow(True)
    ax.grid(True, color=GRID_COLOR, linewidth=0.8, zorder=0)
    for spine_name, spine in ax.spines.items():
        if spine_name in ("top", "right"):
            spine.set_visible(False)
        else:
            spine.set_color(AXIS_COLOR)
    ax.tick_params(colors=MUTED_INK, labelsize=9)
    ax.xaxis.label.set_color(MUTED_INK)
    ax.yaxis.label.set_color(MUTED_INK)


def main():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("--engine", required=True, choices=["crdb", "tidb", "spanner"])
    args = arg_parser.parse_args()

    rows = load_rows(CSV_PATH_TEMPLATE.format(engine=args.engine))
    total_duration = max(row["elapsed_s"] for row in rows)
    bucket_starts, p50s, p99s, error_counts = bucket_rows(rows, total_duration)

    figure, (latency_axis, error_axis) = plt.subplots(
        2, 1, figsize=(11, 6.5), facecolor=CHART_SURFACE, sharex=True,
        gridspec_kw={"height_ratios": [2, 1]},
    )
    figure.suptitle(
        f"Experiment 9 — Fault Tolerance Timeline: {ENGINE_LABELS[args.engine]}",
        fontsize=13, color=PRIMARY_INK, y=0.98,
    )

    style_panel_axis(latency_axis)
    latency_axis.plot(bucket_starts, p50s, marker="o", markersize=3, linewidth=1.5, color=LATENCY_COLOR, label="p50")
    latency_axis.plot(bucket_starts, p99s, marker="o", markersize=3, linewidth=1.5, color=P99_COLOR, label="p99")
    latency_axis.set_ylabel("latency (ms)")
    latency_axis.legend(loc="upper left", frameon=False, fontsize=9, labelcolor=PRIMARY_INK)

    style_panel_axis(error_axis)
    error_axis.bar(bucket_starts, error_counts, width=WINDOW_SEC * 0.9, color=ERROR_COLOR, zorder=3)
    error_axis.set_ylabel(f"failed txns / {WINDOW_SEC}s")
    error_axis.set_xlabel("elapsed time (s)")
    error_axis.set_ylim(bottom=0)

    for ax in (latency_axis, error_axis):
        ax.axvline(KILL_AT_SEC, color=MARKER_COLOR, linestyle="--", linewidth=1.2, zorder=4)
        ax.axvline(RESTART_AT_SEC, color=MARKER_COLOR, linestyle="--", linewidth=1.2, zorder=4)

    latency_axis.text(KILL_AT_SEC, latency_axis.get_ylim()[1], " kill", color=MUTED_INK, fontsize=8, va="top")
    latency_axis.text(RESTART_AT_SEC, latency_axis.get_ylim()[1], " restart", color=MUTED_INK, fontsize=8, va="top")

    figure.tight_layout(rect=[0, 0, 1, 0.95])
    output_path = OUTPUT_PATH_TEMPLATE.format(engine=args.engine)
    figure.savefig(output_path, dpi=150, facecolor=CHART_SURFACE, bbox_inches="tight")
    plt.close(figure)
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
