import sys, pathlib, numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim

ref = np.asarray(Image.open('ref.png')).astype(np.float32) / 255.0
ref_lin = np.power(ref, 2.2)  # crude inverse gamma

def mse(a, b):    return np.mean((a - b) ** 2)
def psnr(a, b):   return -10 * np.log10(mse(a, b))

out = []
for png in pathlib.Path('frames').glob('*.png'):
    test = np.asarray(Image.open(png)).astype(np.float32) / 255.0
    test_lin = np.power(test, 2.2)
    err_mse  = mse(ref_lin, test_lin)
    err_psnr = psnr(ref_lin, test_lin)
    err_ssim = ssim(ref_lin, test_lin, channel_axis=2, data_range=1.0)
    out.append((png.stem, err_mse, err_psnr, err_ssim))
with open('image_error.csv', 'w') as f:
    f.write('label,mse,psnr,ssim\n')
    for row in out:
        f.write(f'{row[0]},{row[1]:.6f},{row[2]:.2f},{row[3]:.4f}\n')
