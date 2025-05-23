

import os, sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from tqdm import tqdm
from quality_metrics import frame_metrics


if len(sys.argv) < 3:
    raise RuntimeError("Usage: plot_quality.py <run> <csv> [frames_dir]")

model      = sys.argv[1]
csv_path   = sys.argv[2]
frames_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.join(
    os.path.dirname(csv_path), "frames")

ref_dir = r"C:\RT\VoluMarch\results\reference"
if not os.path.isdir(ref_dir):
    raise FileNotFoundError(
        f"Reference images not found in\n  {ref_dir}\n"
        "→ run the high-quality reference pass once and store PNGs there.")


from datetime import datetime
timestamp = datetime.now().strftime("%d%m_%H-%M")
out_dir   = os.path.join(r"C:\RT\VoluMarch\plots", f"{model}_quality_{timestamp}")
os.makedirs(out_dir, exist_ok=True)
print(f"[info] output → {out_dir}")


df = pd.read_csv(csv_path)
t_frames = df.frame if "frame" in df.columns else np.arange(len(df))


psnr, ssim = [], []
print(f"[info] comparing {len(t_frames)} frames against reference …")
for f in tqdm(t_frames, desc="quality"):
    ref_png  = os.path.join(ref_dir,   f"f{int(f):04d}.png")
    test_png = os.path.join(frames_dir,f"f{int(f):04d}.png")
    if not (os.path.isfile(ref_png) and os.path.isfile(test_png)):
        raise FileNotFoundError(f"Missing PNG: {ref_png} or {test_png}")
    p, s = frame_metrics(ref_png, test_png)
    psnr.append(p)
    ssim.append(s)

df["psnr"] = psnr
df["ssim"] = ssim


def save(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, name))
    plt.close(fig)

# 1) quality over time
fig = plt.figure(figsize=(10,4))
plt.plot(t_frames, df.psnr, label="PSNR (dB)")
plt.plot(t_frames, df.ssim, label="SSIM", alpha=.7)
plt.axhline(37, ls='--', c='k', alpha=.3)
plt.xlabel("frame")
plt.title("Image quality over time")
plt.legend()
save(fig, "quality_over_time.png")

# 2) cost vs quality (if timing info available)
if "gpu_ms" in df.columns and "totalSteps" in df.columns:
    fig = plt.figure(figsize=(6,6))
    plt.scatter(df.psnr, df.gpu_ms, c=df.totalSteps/1e6, cmap='viridis', s=8, alpha=.6)
    plt.colorbar(label="events (M)")
    plt.xlabel("PSNR (dB)")
    plt.ylabel("GPU ms")
    plt.title("Cost vs quality")
    save(fig, "cost_vs_quality.png")


summary = df[["psnr", "ssim"]].describe()
summary.to_csv(os.path.join(out_dir, "quality_stats.csv"))
print(summary)

with open(os.path.join(out_dir, "quality_summary.csv"), "w") as f:
    f.write("run,psnr,ssim\n")
    f.write(f"{model},{df.psnr.mean():.2f},{df.ssim.mean():.4f}\n")

print("\n[done] quality metrics complete.")
