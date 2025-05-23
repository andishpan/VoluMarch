import pandas as pd, matplotlib.pyplot as plt, numpy as np, os

input_dir  = r"C:\RT\VoluMarch\testResults"
output_dir = r"C:\RT\VoluMarch\plots"
os.makedirs(output_dir, exist_ok=True)

summary_data = []


for file in os.listdir(input_dir):
    if not file.endswith('.csv'):
        continue
    method_name = file.replace('.csv', '')
    df = pd.read_csv(os.path.join(input_dir, file))


    avg_gpu = df['gpu_ms'].mean()
    avg_primary = df['primary'].mean()
    avg_shadow = df['shadow'].mean()
    avg_sdf = df['sdf'].mean()
    avg_bounce = df['bounce'].mean()
    total_steps = df['primary'] + df['shadow'] + df['sdf'] + df['bounce']
    gpu_per_k = df['gpu_ms'] / (total_steps / 1_000.0)
    avg_gpu_per_k = gpu_per_k.mean()


    summary_data.append({
        'Method': method_name,
        'Avg_GPU_ms': avg_gpu,
        'Primary': avg_primary,
        'Shadow': avg_shadow,
        'SDF': avg_sdf,
        'Bounce': avg_bounce,
        'GPU_ms_per_1k': avg_gpu_per_k
    })


summary_df = pd.DataFrame(summary_data)
summary_df = summary_df.sort_values(by='Avg_GPU_ms')


plt.figure(figsize=(10,5))
plt.bar(summary_df['Method'], summary_df['Avg_GPU_ms'])
plt.ylabel('Average GPU Time (ms)')
plt.title('GPU Performance Comparison of Raymarching Methods')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'gpu_time_comparison.png'))
plt.show()


step_labels = ['Primary', 'Shadow', 'SDF', 'Bounce']
bottoms = np.zeros(len(summary_df))

plt.figure(figsize=(10,6))
for step in step_labels:
    plt.bar(summary_df['Method'], summary_df[step]/1e6, bottom=bottoms/1e6, label=step)
    bottoms += summary_df[step]

plt.ylabel('Average Steps (Millions)')
plt.title('Step Distribution per Method')
plt.xticks(rotation=45)
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'step_distribution_comparison.png'))
plt.show()


plt.figure(figsize=(10,5))
plt.bar(summary_df['Method'], summary_df['GPU_ms_per_1k'])
plt.ylabel('GPU ms per 1,000 steps')
plt.title('Hardware Efficiency per Method')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'efficiency_comparison.png'))
plt.show()


summary_df.to_csv(os.path.join(output_dir, 'method_comparison_summary.csv'), index=False)

print("Generated comparison plots and summary CSV.")
