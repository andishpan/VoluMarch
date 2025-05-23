import pandas as pd, matplotlib.pyplot as plt, numpy as np, os


model_csvs = {
    "Model_A": r"C:\RT\VoluMarch\testResults\currentnoise_modelA.csv",
    "Model_B": r"C:\RT\VoluMarch\testResults\currentnoise_modelB.csv",

}

out_dir = r"C:\RT\VoluMarch\plots\comparison"
os.makedirs(out_dir, exist_ok=True)


dfs = {}
for label, path in model_csvs.items():
    df = pd.read_csv(path)
    df["fps_gpu"] = 1000.0 / df.gpu_ms
    df["fps_cpu"] = 1000.0 / df.cpu_ms
    df["totalSteps"] = df.primary + df.shadow + df.sdf + df.bounce
    df["gpu_per_k"] = df.gpu_ms / (df.totalSteps / 1_000.0)
    df["bounce_ratio"] = df.bounce / df.primary
    dfs[label] = df


plt.figure(figsize=(10,5))
for label, df in dfs.items():
    plt.plot(df.frame, df.fps_gpu, label=f"{label} GPU FPS")
plt.xlabel("Frame")
plt.ylabel("FPS (GPU)")
plt.title("GPU Throughput Comparison")
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(out_dir, "gpu_fps_comparison.png"))
plt.show()


plt.figure(figsize=(8,6))
for label, df in dfs.items():
    plt.scatter(df.totalSteps/1e6, df.gpu_ms, s=6, alpha=0.6, label=label)
    m, b = np.polyfit(df.totalSteps/1e6, df.gpu_ms, 1)
    plt.plot(df.totalSteps/1e6, m*df.totalSteps/1e6 + b, label=f"{label} Fit: {m:.2f} ms/M")
plt.xlabel("Total March Events (M)")
plt.ylabel("GPU Time (ms)")
plt.title("GPU Time vs Work Comparison")
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(out_dir, "gpu_time_vs_work_comparison.png"))
plt.show()


plt.figure(figsize=(10,5))
for label, df in dfs.items():
    plt.plot(df.frame, df.gpu_per_k, label=f"{label} ms per 1k steps")
    plt.axhline(df.gpu_per_k.mean(), ls="--", alpha=0.5, label=f"{label} avg {df.gpu_per_k.mean():.4f} ms/1k")
plt.xlabel("Frame")
plt.ylabel("GPU ms per 1 000 events")
plt.title("Hardware Efficiency Comparison")
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(out_dir, "gpu_efficiency_comparison.png"))
plt.show()


plt.figure(figsize=(10,5))
for label, df in dfs.items():
    plt.plot(df.frame, df.bounce_ratio, label=f"{label} Bounce Ratio")
    plt.axhline(df.bounce_ratio.mean(), ls="--", alpha=0.5, label=f"{label} avg {df.bounce_ratio.mean():.2f}")
plt.xlabel("Frame")
plt.ylabel("Bounce : Primary Ratio")
plt.title("Scattering vs Primary March Comparison")
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(out_dir, "bounce_ratio_comparison.png"))
plt.show()


with open(os.path.join(out_dir, "comparison_summary.txt"), "w") as f:
    for label, df in dfs.items():
        summary = df[["gpu_ms","totalSteps","gpu_per_k","bounce"]].describe()
        f.write(f"Summary statistics for {label}:\n\n")
        f.write(summary.to_string())
        f.write("\n\n" + "-"*60 + "\n\n")

print("Comparison plots and summaries saved to:", out_dir)
