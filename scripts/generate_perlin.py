import numpy as np
from noise import pnoise3
from tqdm import tqdm


shape = (64, 64, 64)
scale = 0.1
octaves = 4
persistence = 0.5
lacunarity = 2.0
seed = 0



def generate_perlin_volume(shape, scale, octaves, persistence, lacunarity, seed=0):
    vol = np.zeros(shape, dtype=np.float32)
    for z in tqdm(range(shape[0]), desc="Z"):
        for y in range(shape[1]):
            for x in range(shape[2]):
                vol[z, y, x] = pnoise3(x * scale, y * scale, z * scale,
                                       octaves=octaves,
                                       persistence=persistence,
                                       lacunarity=lacunarity,
                                       repeatx=shape[2],
                                       repeaty=shape[1],
                                       repeatz=shape[0],
                                       base=seed)
    return vol



volume = generate_perlin_volume(shape, scale, octaves, persistence, lacunarity, seed=seed)


with open("perlin_noise_64x64x64.bin", "wb") as f:
    volume.tofile(f)

print("Perlin noise generated.")
