#!/usr/bin/env python3
import sys
from pathlib import Path

import matplotlib.pyplot as plt

if len(sys.argv) != 3:
    print("Usage: render-markdown-table.py input.md output.png")
    sys.exit(1)

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

lines = [
    line.strip()
    for line in input_path.read_text(encoding="utf-8").splitlines()
    if line.strip().startswith("|")
]

if len(lines) < 3:
    print(f"No Markdown table found in {input_path}")
    sys.exit(1)

header = [cell.strip() for cell in lines[0].strip("|").split("|")]
rows = []

for line in lines[2:]:
    cells = [cell.strip().strip("`") for cell in line.strip("|").split("|")]
    rows.append(cells)

fig_width = 14
fig_height = max(2.5, 0.42 * (len(rows) + 1))

fig, ax = plt.subplots(figsize=(fig_width, fig_height))
ax.axis("off")

table = ax.table(
    cellText=rows,
    colLabels=header,
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
