import numpy as np
from noise import snoise3
from tqdm import tqdm

shape = (64, 64, 64)
scale = 0.1
octaves = 8
persistence = 0.5
lacunarity = 2.0
seed = 0


def generate_perlin_volume(shape, scale, octaves, persistence, lacunarity):
    vol = np.zeros(shape, dtype=np.float32)
    for z in tqdm(range(shape[0]), desc="Z"):
        for y in range(shape[1]):
            for x in range(shape[2]):
                vol[z, y, x] = snoise3(
                    x * scale,
                    y * scale,
                    z * scale,
                    octaves=octaves,
                    persistence=persistence,
                    lacunarity=lacunarity
                )
    return vol


volume = generate_perlin_volume(shape, scale, octaves, persistence, lacunarity)

with open("simplex_noise_64x64x64.bin", "wb") as f:
    volume.tofile(f)

print("Simplex noise  generated.")
