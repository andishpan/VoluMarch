#
import os, sys, math
from datetime import datetime
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


if len(sys.argv) < 3:
    raise RuntimeError("Usage: plot_data.py <run> <csv> [frames_dir]")

model      = sys.argv[1]
csv_path   = sys.argv[2]
frames_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
    os.path.dirname(csv_path), "frames")


timestamp = datetime.now().strftime("%d%m_%H-%M")
out_dir   = os.path.join(r"C:\RT\VoluMarch\plots", f"{model}_{timestamp}")
os.makedirs(out_dir, exist_ok=True)
print(f"[info] output → {out_dir}")


df = pd.read_csv(csv_path)
need = {"pixels", "bounce", "gpu_ms"}
miss = need - set(df.columns)
if miss:
    raise RuntimeError(f"CSV missing column(s): {', '.join(miss)}")


df["fps_gpu"]    = 1000.0 / df.gpu_ms
df["fps_cpu"]    = 1000.0 / df.cpu_ms if "cpu_ms" in df else np.nan
df["totalSteps"] = df.primary + df.shadow + df.sdf + df.bounce
df["gpu_per_k"]  = df.gpu_ms / (df.totalSteps / 1_000.0)
df["ms_per_mp"]  = df.gpu_ms / (df.pixels   / 1_000_000.0)
df["bounce_ratio"] = df.bounce / df.primary
t_frames = df.frame if "frame" in df.columns else np.arange(len(df))


def save(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, name))
    plt.close(fig)

# 1) FPS history
fig = plt.figure(figsize=(10,4))
plt.plot(t_frames, df.fps_gpu, label="GPU FPS")
if df.fps_cpu.notna().any():
    plt.plot(t_frames, df.fps_cpu, label="CPU FPS", alpha=.5)
plt.axhline(df.fps_gpu.mean(), ls="--", label=f"avg {df.fps_gpu.mean():.1f} FPS")
plt.xlabel("frame"); plt.ylabel("frames / s"); plt.title("Throughput over time"); plt.legend()
save(fig, "throughput.png")

# 2) GPU time vs work
fig = plt.figure(figsize=(6,6))
plt.scatter(df.totalSteps/1e6, df.gpu_ms, s=6)
coef, _ = np.polyfit(df.totalSteps/1e6, df.gpu_ms, 1)
plt.plot(df.totalSteps/1e6, coef*df.totalSteps/1e6, "r",
         label=f"{coef:.2f} ms / M-event")
plt.xlabel("events (×10⁶)"); plt.ylabel("GPU ms"); plt.title("Cost vs work"); plt.legend()
save(fig, "time_vs_work.png")

# 3) work-mix area
bins  = np.linspace(t_frames.min(), t_frames.max(), 40).astype(int)
chunk = df.groupby(np.digitize(t_frames, bins))
(chunk[["primary","shadow","sdf","bounce"]].mean()/1e6) \
    .plot.area(stacked=True, figsize=(10,4), colormap="tab20")
plt.ylabel("events (×10⁶)"); plt.xlabel("time-chunk"); plt.title("Work mix")
save(plt.gcf(), "work_mix.png")

# 4) efficiency triple-axis
fig, ax  = plt.subplots(figsize=(11,4))
ax2, ax3 = ax.twinx(), ax.twinx()
ax3.spines.right.set_position(("outward", 60))
ax.semilogy(t_frames, df.gpu_per_k,        'b', lw=.8, label='ms / kStep')
ax2.plot   (t_frames, df.ms_per_mp,        'orange', lw=.8, label='ms / MPix')
ax3.plot   (t_frames, df.totalSteps/1e6,   'red', lw=1, alpha=.25, label='events (M)')
ax.set_ylim(5e-4, 1e-3)
ax.set_title("Hardware efficiency"); ax.set_xlabel("frame")
ax.set_ylabel("ms / kStep  (log)");  ax2.set_ylabel("GPU ms / frame");  ax3.set_ylabel("events (M)")
h,l=[],[]
for a in (ax,ax2,ax3):
    h2,l2 = a.get_legend_handles_labels(); h+=h2; l+=l2
ax.legend(h,l,loc='upper left')
save(fig, "efficiency.png")

# 5) density scatter
fig = plt.figure(figsize=(10,4))
df['work_per_px'] = df.totalSteps/df.pixels
plt.scatter(df.work_per_px, df.gpu_per_k, s=6, alpha=.3)
m,b = np.polyfit(df.work_per_px, df.gpu_per_k,1)
plt.plot(df.work_per_px, m*df.work_per_px+b,'r',
         label=f"slope {m:.3g} ms / (k·event/px)")
plt.xlabel("steps / pixel"); plt.ylabel("ms / kStep"); plt.legend()
plt.title("Cost per step vs workload density")
save(fig, "step_cost_vs_density.png")

# 6) bounce ratio
fig = plt.figure(figsize=(10,4))
plt.plot(t_frames, df.bounce_ratio)
plt.axhline(df.bounce_ratio.mean(), ls='--',
            label=f"avg {df.bounce_ratio.mean():.2f}")
plt.xlabel("frame"); plt.ylabel("bounce / primary"); plt.legend()
plt.title("Scatters per view-march")
save(fig, "bounce_ratio.png")


summary = df[["gpu_ms","totalSteps","gpu_per_k","bounce"]].describe()
summary.to_csv(os.path.join(out_dir,"summary_stats.csv"))
print(summary)

with open(os.path.join(out_dir,"run_summary.csv"),"w") as f:
    f.write("run,gpu_ms,ms_per_kstep,bounce_ratio\n")
    f.write(f"{model},{df.gpu_ms.mean():.2f},{df.gpu_per_k.mean():.5f},"
            f"{df.bounce_ratio.mean():.3f}\n")

print("\n[done] all plots written.")
