import pandas as pd
import matplotlib.pyplot as plt

def plot(csv, label):
    df = pd.read_csv(csv)

    cpu_avg = df['cpu_ms'].mean()
    gpu_avg = df['gpu_ms'].mean()

    print(f"{label}:")
    print(f"  CPU time: {cpu_avg:.2f} ms ({1000 / cpu_avg:.1f} FPS)")
    print(f"  GPU time: {gpu_avg:.2f} ms ({1000 / gpu_avg:.1f} FPS)\n")

    plt.plot(df['frame'], df['cpu_ms'], label=f"{label} CPU ({cpu_avg:.1f} ms)")
    plt.plot(df['frame'], df['gpu_ms'], label=f"{label} GPU ({gpu_avg:.1f} ms)", linestyle='--')

plt.figure(figsize=(10, 5))
plot(r"C:\RT\VoluMarch\testResults\perlin.csv",   "Perlin")
# plot("bench/worley.csv",   "Worley")
# plot("bench/precomp.csv",  "Precomputed 3D")

plt.xlabel("Frame #")
plt.ylabel("Frame Time (ms)")
plt.title("Volumetric Shader Benchmark (CPU vs GPU)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()
