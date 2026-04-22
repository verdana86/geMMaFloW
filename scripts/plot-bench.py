#!/usr/bin/env python3
"""Parses bench/results.md and renders three charts under bench/charts/:

1. latency-stacked.png — grouped bars showing Whisper + Gemma times stacked
   per (length, combo), so the total cost of each pipeline is visible at a
   glance.
2. latency-scaling.png — line chart of total latency vs audio length for
   each (whisper, gemma) pair. Highlights how each combo scales.
3. realtime-factor.png — total latency / audio_seconds. A value <1 means
   the pipeline is faster than real-time.
"""

from __future__ import annotations
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS = REPO_ROOT / "bench" / "results.md"
OUT_DIR = REPO_ROOT / "bench" / "charts"

# Length label → audio seconds (full is 81s based on the generated TTS).
LENGTH_SECONDS = {"20s": 20, "40s": 40, "60s": 60, "full": 81}
LENGTH_ORDER = ["20s", "40s", "60s", "full"]
COMBO_ORDER = [
    ("Whisper Small", "Qwen 1.5B"),
    ("Whisper Small", "Gemma E2B"),
    ("Whisper Small", "Gemma E4B"),
    ("Whisper Large", "Qwen 1.5B"),
    ("Whisper Large", "Gemma E2B"),
    ("Whisper Large", "Gemma E4B"),
]
COMBO_COLORS = {
    ("Whisper Small", "Qwen 1.5B"): "#FF9800",
    ("Whisper Small", "Gemma E2B"): "#4CAF50",
    ("Whisper Small", "Gemma E4B"): "#8BC34A",
    ("Whisper Large", "Qwen 1.5B"): "#E91E63",
    ("Whisper Large", "Gemma E2B"): "#2196F3",
    ("Whisper Large", "Gemma E4B"): "#0D47A1",
}


def parse_results() -> list[dict]:
    text = RESULTS.read_text()
    rows = []
    table_re = re.compile(
        r"^\|\s*(20s|40s|60s|full)\s*\|\s*(Whisper Small|Whisper Large)\s*\|"
        r"\s*(Qwen 1\.5B|Gemma E2B|Gemma E4B)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|",
        re.MULTILINE,
    )
    for m in table_re.finditer(text):
        rows.append({
            "length": m.group(1),
            "whisper": m.group(2),
            "gemma": m.group(3),
            "whisper_ms": int(m.group(4)),
            "gemma_ms": int(m.group(5)),
            "total_ms": int(m.group(6)),
        })
    if not rows:
        print(f"error: no rows parsed from {RESULTS}", file=sys.stderr)
        sys.exit(1)
    return rows


def plot_stacked(rows: list[dict]) -> Path:
    """Stacked bars: whisper time + gemma time per (length × combo). Four
    groups of four bars."""
    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(LENGTH_ORDER))
    width = 0.2

    for i, combo in enumerate(COMBO_ORDER):
        whisper_vals = []
        gemma_vals = []
        for length in LENGTH_ORDER:
            row = next(
                (r for r in rows
                 if r["length"] == length
                 and r["whisper"] == combo[0]
                 and r["gemma"] == combo[1]),
                None,
            )
            whisper_vals.append((row["whisper_ms"] if row else 0) / 1000)
            gemma_vals.append((row["gemma_ms"] if row else 0) / 1000)

        offset = (i - 1.5) * width
        label = f"{combo[0].replace('Whisper ', '')} + {combo[1].replace('Gemma ', '')}"
        ax.bar(x + offset, whisper_vals, width,
               color=COMBO_COLORS[combo], alpha=0.55,
               label=f"{label} — Whisper")
        ax.bar(x + offset, gemma_vals, width,
               bottom=whisper_vals,
               color=COMBO_COLORS[combo], alpha=1.0,
               label=f"{label} — Gemma")

    # Label every bar with its total latency so numbers are readable at a
    # glance without hunting the y-axis.
    for i, combo in enumerate(COMBO_ORDER):
        offset = (i - 1.5) * width
        for xi, length in enumerate(LENGTH_ORDER):
            row = next(
                (r for r in rows
                 if r["length"] == length
                 and r["whisper"] == combo[0]
                 and r["gemma"] == combo[1]),
                None,
            )
            if not row:
                continue
            total = (row["whisper_ms"] + row["gemma_ms"]) / 1000
            ax.text(xi + offset, total + 1.5, f"{total:.0f}s",
                    ha="center", va="bottom", fontsize=7, color="#333")

    ax.set_xticks(x)
    ax.set_xticklabels([f"{LENGTH_SECONDS[l]} s audio" for l in LENGTH_ORDER])
    ax.set_ylabel("Pipeline latency (seconds)")
    ax.set_title("Pipeline latency by combo — Whisper (light) + Gemma (solid)")
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.0f} s"))
    ax.legend(loc="upper left", fontsize=8, ncol=2)
    ax.grid(True, axis="y", alpha=0.3)
    ax.set_axisbelow(True)

    out = OUT_DIR / "latency-stacked.png"
    fig.tight_layout()
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def plot_scaling(rows: list[dict]) -> Path:
    """Line chart: total latency vs audio length for each combo."""
    fig, ax = plt.subplots(figsize=(10, 6))
    audio_seconds = [LENGTH_SECONDS[l] for l in LENGTH_ORDER]

    for combo in COMBO_ORDER:
        totals = []
        for length in LENGTH_ORDER:
            row = next(
                (r for r in rows
                 if r["length"] == length
                 and r["whisper"] == combo[0]
                 and r["gemma"] == combo[1]),
                None,
            )
            totals.append((row["total_ms"] if row else 0) / 1000)
        label = f"{combo[0].replace('Whisper ', 'W-')} + {combo[1].replace('Gemma ', 'G-')}"
        ax.plot(audio_seconds, totals, "-o", color=COMBO_COLORS[combo],
                linewidth=2, markersize=8, label=label)

    # Diagonal: real-time line (latency == audio length).
    ax.plot(audio_seconds, audio_seconds, "--", color="gray", alpha=0.5,
            label="real-time (latency = audio duration)")

    ax.set_xlabel("Audio length (seconds)")
    ax.set_ylabel("Total pipeline latency (seconds)")
    ax.set_title("Total latency scaling vs audio length")
    ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.0f} s"))
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.0f} s"))
    ax.legend(loc="upper left", fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_axisbelow(True)

    out = OUT_DIR / "latency-scaling.png"
    fig.tight_layout()
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def plot_realtime_factor(rows: list[dict]) -> Path:
    """Bars: realtime factor = total_ms / audio_s / 1000. <1 = faster than
    realtime."""
    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(LENGTH_ORDER))
    width = 0.2

    for i, combo in enumerate(COMBO_ORDER):
        factors = []
        for length in LENGTH_ORDER:
            row = next(
                (r for r in rows
                 if r["length"] == length
                 and r["whisper"] == combo[0]
                 and r["gemma"] == combo[1]),
                None,
            )
            audio_s = LENGTH_SECONDS[length]
            factors.append(((row["total_ms"] if row else 0) / 1000) / audio_s)

        offset = (i - 1.5) * width
        label = f"{combo[0].replace('Whisper ', 'W-')} + {combo[1].replace('Gemma ', 'G-')}"
        ax.bar(x + offset, factors, width, color=COMBO_COLORS[combo], label=label)

    # Label every bar with its numeric factor so the magnitude is explicit.
    for i, combo in enumerate(COMBO_ORDER):
        offset = (i - 1.5) * width
        for xi, length in enumerate(LENGTH_ORDER):
            row = next(
                (r for r in rows
                 if r["length"] == length
                 and r["whisper"] == combo[0]
                 and r["gemma"] == combo[1]),
                None,
            )
            if not row:
                continue
            factor = (row["total_ms"] / 1000) / LENGTH_SECONDS[length]
            ax.text(xi + offset, factor + 0.05, f"{factor:.2f}×",
                    ha="center", va="bottom", fontsize=7, color="#333")

    ax.axhline(1.0, color="red", linestyle="--", linewidth=1, alpha=0.7,
               label="real-time threshold (1.0×)")
    ax.set_xticks(x)
    ax.set_xticklabels([f"{LENGTH_SECONDS[l]} s audio" for l in LENGTH_ORDER])
    ax.set_ylabel("Realtime factor (× audio duration)")
    ax.set_title("Realtime factor — values <1× mean faster than real-time")
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.1f}×"))
    ax.legend(loc="upper right", fontsize=9)
    ax.grid(True, axis="y", alpha=0.3)
    ax.set_axisbelow(True)

    out = OUT_DIR / "realtime-factor.png"
    fig.tight_layout()
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = parse_results()
    print(f"parsed {len(rows)} rows from {RESULTS}")
    for fn in (plot_stacked, plot_scaling, plot_realtime_factor):
        out = fn(rows)
        print(f"  ✓ {out.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
