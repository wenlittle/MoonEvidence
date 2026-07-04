# -*- coding: utf-8 -*-
"""Plot the real verify timing sweep (_bench_data.csv) into mev_perf.png."""
import csv
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei"]
plt.rcParams["axes.unicode_minus"] = False

HERE = os.path.dirname(os.path.abspath(__file__))
xs, ys = [], []
with open(os.path.join(HERE, "_bench_data.csv"), encoding="utf-8") as f:
    r = csv.reader(f)
    next(r)
    for row in r:
        xs.append(int(row[0]))
        ys.append(float(row[1]))

xs = np.array(xs)
ys = np.array(ys)
a, b = np.polyfit(xs, ys, 1)  # linear fit y = a*x + b
yhat = a * xs + b
ss_res = np.sum((ys - yhat) ** 2)
ss_tot = np.sum((ys - ys.mean()) ** 2)
r2 = 1 - ss_res / ss_tot

fig, ax = plt.subplots(figsize=(7.2, 4.4), dpi=150)
xf = np.linspace(xs.min(), xs.max(), 100)
ax.plot(xf, a * xf + b, "-", color="#3a6ea5", linewidth=2,
        label=f"线性拟合  T ≈ {a*1000:.3f}·(N/1000) + {b:.0f} ms   (R²={r2:.3f})")
ax.plot(xs, ys, "o", color="#e0574f", markersize=8, label="实测端到端耗时 (js 后端)")
for x, y in zip(xs, ys):
    ax.annotate(f"{y:.0f}", (x, y), textcoords="offset points",
                xytext=(0, 9), ha="center", fontsize=9, color="#333333")

ax.set_xlabel("证据包文件数 N", fontsize=12)
ax.set_ylabel("端到端 verify 耗时 / ms（含运行时启动）", fontsize=12)
ax.set_title("全量验证耗时随文件数近线性增长", fontsize=14, fontweight="bold")
ax.grid(True, linestyle="--", alpha=0.4)
ax.legend(fontsize=10, loc="upper left")
fig.tight_layout()
out = os.path.join(HERE, "screenshots", "mev_perf.png")
fig.savefig(out)
print("saved", out, "slope(ms/1k files)=%.3f" % (a * 1000), "R2=%.4f" % r2)
