import numpy as np
from skimage.metrics import structural_similarity, peak_signal_noise_ratio
from imageio import imread

def psnr(imgA, imgB):

    return peak_signal_noise_ratio(imgA, imgB, data_range=255)

def ssim(imgA, imgB):

    return structural_similarity(imgA, imgB, channel_axis=-1, data_range=255)

def frame_metrics(ref_path, test_path):
    ref  = imread(ref_path)
    test = imread(test_path)

    if ref.shape != test.shape:
        raise ValueError(f"[error] Image shape mismatch:\n  {ref_path}: {ref.shape}\n  {test_path}: {test.shape}")

    if ref.size == 0 or test.size == 0:
        raise ValueError(f"[error] Empty image data:\n  {ref_path} or {test_path}")

    return psnr(ref, test), ssim(ref, test)
