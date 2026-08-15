#!/usr/bin/env python3
"""
Experiment 7 — chart generation from bench_results.csv.

Per the runbook's R3, throughput and latency are rendered as
side-by-side panels (one per engine/deployment), each with its OWN y-axis — never a
single shared axis with three lines, which would invite reading off a
winner. Color encodes workload (point_read / point_write / transfer), held
in the same fixed order and hue across all three panels, so identity never
shifts with the engine. Median-of-3-reps is the plotted line; the shaded
band around it is the min-max spread across those reps.

Usage:
    source .venv/bin/activate
    python3 experiments/07_benchmark/make_charts.py
"""
import csv
from collections import defaultdict
from statistics import median

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

CSV_PATH = "experiments/07_benchmark/bench_results.csv"
OUTPUT_DIR = "results/benchmark_charts"

ENGINES = ["crdb", "tidb", "spanner", "spanner_multi"]
ENGINE_LABELS = {
    "crdb": "CockroachDB (RF=3)",
    "tidb": "TiDB (RF=3)",
    "spanner": "Spanner Omni (RF=1, software TrueTime)",
    "spanner_multi": "Spanner Omni (RF=3, software TrueTime)",
}
WORKLOADS = ["point_read", "point_write", "transfer"]
WORKLOAD_LABELS = {"point_read": "point read", "point_write": "point write", "transfer": "transfer txn"}
WORKLOAD_COLORS = {"point_read": "#2a78d6", "point_write": "#eb6834", "transfer": "#1baf7a"}
CONCURRENCY_LEVELS = [1, 4, 16, 32, 64]

CHART_SURFACE = "#fcfcfb"
GRID_COLOR = "#e1e0d9"
AXIS_COLOR = "#c3c2b7"
MUTED_INK = "#898781"
PRIMARY_INK = "#0b0b0b"


def load_result_rows():
    result_rows = []
    with open(CSV_PATH) as csv_file:
        for row in csv.DictReader(csv_file):
            row["concurrency"] = int(row["concurrency"])
            row["rep"] = int(row["rep"])
            row["ops_per_sec"] = float(row["ops_per_sec"])
            row["p50"] = float(row["p50"])
            row["p95"] = float(row["p95"])
            row["p99"] = float(row["p99"])
            row["retries"] = int(row["retries"])
            result_rows.append(row)
    return result_rows


def aggregate_reps_by_metric(result_rows, metric_name):
    values_by_key = defaultdict(list)
    for row in result_rows:
        key = (row["engine"], row["workload"], row["concurrency"])
        values_by_key[key].append(row[metric_name])

    stats_by_key = {}
    for key, values in values_by_key.items():
        stats_by_key[key] = (median(values), min(values), max(values))
    return stats_by_key


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


def render_panelled_chart(result_rows, metric_name, y_axis_label, chart_title, output_filename, use_log_y_scale=False):
    stats_by_key = aggregate_reps_by_metric(result_rows, metric_name)

    figure, panel_axes = plt.subplots(1, len(ENGINES), figsize=(5 * len(ENGINES), 4.5), facecolor=CHART_SURFACE)
    figure.suptitle(chart_title, fontsize=13, color=PRIMARY_INK, y=1.05)
    figure.text(
        0.5, 0.985,
        "Each panel is one engine on its own y-axis — not a cross-engine ranking (runbook R3).",
        ha="center", fontsize=8.5, color=MUTED_INK,
    )

    for panel_axis, engine in zip(panel_axes, ENGINES):
        style_panel_axis(panel_axis)
        for workload in WORKLOADS:
            concurrency_values, median_values, low_values, high_values = [], [], [], []
            for concurrency in CONCURRENCY_LEVELS:
                key = (engine, workload, concurrency)
                if key not in stats_by_key:
                    continue
                median_value, low_value, high_value = stats_by_key[key]
                concurrency_values.append(concurrency)
                median_values.append(median_value)
                low_values.append(low_value)
                high_values.append(high_value)
            if not concurrency_values:
                continue

            workload_color = WORKLOAD_COLORS[workload]
            panel_axis.plot(
                concurrency_values, median_values, marker="o", markersize=5, linewidth=2,
                color=workload_color, label=WORKLOAD_LABELS[workload], zorder=3,
            )
            panel_axis.fill_between(
                concurrency_values, low_values, high_values,
                color=workload_color, alpha=0.15, linewidth=0, zorder=2,
            )

        panel_axis.set_xscale("log", base=2)
        panel_axis.set_xticks(CONCURRENCY_LEVELS)
        panel_axis.get_xaxis().set_major_formatter(mticker.ScalarFormatter())
        panel_axis.set_xlabel("concurrency (threads)")
        if use_log_y_scale:
            panel_axis.set_yscale("log")
        else:
            panel_axis.set_ylim(bottom=0)
        panel_axis.set_ylabel(y_axis_label)
        panel_axis.set_title(ENGINE_LABELS[engine], fontsize=11, color=PRIMARY_INK, loc="left")

    legend_handles, legend_labels = panel_axes[0].get_legend_handles_labels()
    figure.legend(
        legend_handles, legend_labels, loc="lower center", ncol=3, bbox_to_anchor=(0.5, -0.04),
        frameon=False, fontsize=9, labelcolor=PRIMARY_INK,
    )

    figure.tight_layout(rect=[0, 0.02, 1, 0.93])
    output_path = f"{OUTPUT_DIR}/{output_filename}"
    figure.savefig(output_path, dpi=150, facecolor=CHART_SURFACE, bbox_inches="tight")
    plt.close(figure)
    print(f"Wrote {output_path}")


def main():
    result_rows = load_result_rows()

    render_panelled_chart(
        result_rows, metric_name="ops_per_sec", y_axis_label="ops/sec (log scale)",
        chart_title="Experiment 7 — Throughput vs. Concurrency",
        output_filename="exp7_throughput.png", use_log_y_scale=True,
    )
    render_panelled_chart(
        result_rows, metric_name="p99", y_axis_label="p99 latency, ms (log scale)",
        chart_title="Experiment 7 — p99 Latency vs. Concurrency",
        output_filename="exp7_latency_p99.png", use_log_y_scale=True,
    )
    render_panelled_chart(
        result_rows, metric_name="retries", y_axis_label="retries per 30s run",
        chart_title="Experiment 7 — Retry Count vs. Concurrency (the interesting one)",
        output_filename="exp7_retry_rate.png", use_log_y_scale=False,
    )


if __name__ == "__main__":
    main()
