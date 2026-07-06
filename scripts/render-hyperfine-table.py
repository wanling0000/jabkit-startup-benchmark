#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

import matplotlib.pyplot as plt

if len(sys.argv) != 3:
    print("Usage: render-hyperfine-table.py input.json output.png")
    sys.exit(1)

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

data = json.loads(input_path.read_text())
results = data["results"]

items = []
for result in results:
    items.append({
        "command": result["command"],
        "mean": result["mean"],
        "stddev": result["stddev"],
        "min": result["min"],
        "max": result["max"],
    })

items.sort(key=lambda item: item["mean"])

best = items[0]
best_mean = best["mean"]
best_stddev = best["stddev"]

rows = []
for item in items:
    relative = item["mean"] / best_mean
    if item is best:
        relative_text = "1.00"
    else:
        relative_stddev = relative * math.sqrt(
            (item["stddev"] / item["mean"]) ** 2
            + (best_stddev / best_mean) ** 2
        )
        relative_text = f"{relative:.2f} ± {relative_stddev:.2f}"

    rows.append([
        item["command"],
        f"{item['mean']:.3f} ± {item['stddev']:.3f}",
        f"{item['min']:.3f}",
        f"{item['max']:.3f}",
        relative_text,
    ])

columns = ["Command", "Mean [s]", "Min [s]", "Max [s]", "Relative"]

row_count = len(rows)
fig_height = max(2.0, 0.42 * (row_count + 1))
fig_width = 14 if row_count > 10 else 10

fig, ax = plt.subplots(figsize=(fig_width, fig_height))
ax.axis("off")

table = ax.table(
    cellText=rows,
    colLabels=columns,
    loc="center",
    cellLoc="left",
    colLoc="left",
    colWidths=[0.48, 0.18, 0.11, 0.11, 0.12],
)

table.auto_set_font_size(False)
table.set_fontsize(9)
table.scale(1, 1.35)

for (row, col), cell in table.get_celld().items():
    cell.set_edgecolor("#d0d7de")
    cell.set_linewidth(0.6)
    if row == 0:
        cell.set_facecolor("#f6f8fa")
        cell.set_text_props(weight="bold")
    else:
        cell.set_facecolor("#ffffff" if row % 2 else "#fbfbfb")

plt.tight_layout()
plt.savefig(output_path, dpi=220, bbox_inches="tight")
