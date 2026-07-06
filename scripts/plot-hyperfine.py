#!/usr/bin/env python3
import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt

if len(sys.argv) != 4:
    print("Usage: plot-hyperfine.py input.json output.png title")
    sys.exit(1)

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
title = sys.argv[3]

data = json.loads(input_path.read_text())

items = []
for result in data["results"]:
    items.append((
        result["command"],
        result["mean"],
        result["stddev"],
    ))

items.sort(key=lambda item: item[1], reverse=True)

labels = [item[0] for item in items]
means = [item[1] for item in items]
errors = [item[2] for item in items]

height = max(4.5, 0.38 * len(items) + 1.5)

plt.figure(figsize=(11, height))
bars = plt.barh(labels, means, xerr=errors, capsize=4)

plt.xlabel("Startup time for jabkit --help (seconds)")
plt.title(title)
plt.grid(axis="x", linestyle="--", alpha=0.35)

for bar, mean, stddev in zip(bars, means, errors):
    plt.text(
        mean + stddev + 0.12,
        bar.get_y() + bar.get_height() / 2,
        f"{mean:.2f}s ± {stddev:.2f}s",
        va="center",
        fontsize=8,
    )

plt.tight_layout()
plt.savefig(output_path, dpi=200)
