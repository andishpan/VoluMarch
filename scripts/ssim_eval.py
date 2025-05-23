import os
from skimage.metrics import structural_similarity as ssim
from imageio import imread
import numpy as np


ref_dir = r"C:\RT\VoluMarch\results\reference"
cur_dir = r"C:\RT\VoluMarch\results\frames"

frame_range = range(0, 512)

ssim_scores = []

for f in frame_range:
    fname = f"mask{f:04d}.png"
    ref_path = os.path.join(ref_dir, fname)
    cur_path = os.path.join(cur_dir, fname)

    if not os.path.isfile(ref_path) or not os.path.isfile(cur_path):
        print(f"[warn] Missing: {fname}")
        continue


    ref_img = imread(ref_path)
    cur_img = imread(cur_path)


    if ref_img.shape != cur_img.shape:
        print(f"[error] Shape mismatch in {fname}: {ref_img.shape} vs {cur_img.shape}")
        continue


    try:
        score = ssim(ref_img, cur_img, channel_axis=-1, data_range=255)
        ssim_scores.append(score)
        print(f"{fname}: SSIM = {score:.4f}")
    except Exception as e:
        print(f"[error] Failed to compute SSIM for {fname}: {e}")


if ssim_scores:
    print(f"\nAverage SSIM over {len(ssim_scores)} frames: {np.mean(ssim_scores):.4f}")
else:
    print("No valid SSIM scores computed.")
