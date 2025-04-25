import pandas as pd
import matplotlib.pyplot as plt

def plot(csv, label):
    df = pd.read_csv(csv)
    avg = df['ms'].mean()
    print(f"{csv}: {avg:.2f} ms  ({1000/avg:.1f} FPS)")
    plt.plot(df['frame'], df['ms'], label=f"{label}  ({avg:.1f} ms)")

plt.figure(figsize=(8,4))
plot(r"C:\RT\VoluMarch\testResults\perlin.csv",   "Perlin")
#plot("bench/worley.csv",   "Worley")
#plot("bench/precomp.csv",  "Precomputed 3‑D")

plt.xlabel("Frame #")
plt.ylabel("Frame time (ms)")
plt.title("Volumetric shader benchmark – fixed view")
plt.legend()
plt.tight_layout()
plt.show()
