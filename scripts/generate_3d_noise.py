import numpy as np
import struct
from noise import snoise3
import random
from scipy.spatial import cKDTree
import os


SIZE = 256
SCALE = 0.05
OCTAVES = 4

OUTPUT_DIR = "output_noise"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def save_bin(data, filename):
    data.astype(np.float32).tofile(filename)
    print(f"Saved: {filename}")

def generate_simplex():
    data = np.zeros((SIZE, SIZE, SIZE), dtype=np.float32)
    for z in range(SIZE):
        for y in range(SIZE):
            for x in range(SIZE):
                nx, ny, nz = x * SCALE, y * SCALE, z * SCALE
                data[x, y, z] = snoise3(nx, ny, nz, octaves=OCTAVES)
    return data

def generate_fbm():
    data = np.zeros((SIZE, SIZE, SIZE), dtype=np.float32)
    for z in range(SIZE):
        for y in range(SIZE):
            for x in range(SIZE):
                nx, ny, nz = x * SCALE, y * SCALE, z * SCALE
                value = 0.0
                amplitude = 1.0
                frequency = 1.0
                for _ in range(OCTAVES):
                    value += snoise3(nx * frequency, ny * frequency, nz * frequency) * amplitude
                    amplitude *= 0.5
                    frequency *= 2.0
                data[x, y, z] = value
    return data

def generate_ridged():
    data = np.zeros((SIZE, SIZE, SIZE), dtype=np.float32)
    for z in range(SIZE):
        for y in range(SIZE):
            for x in range(SIZE):
                nx, ny, nz = x * SCALE, y * SCALE, z * SCALE
                value = 0.0
                amplitude = 1.0
                frequency = 1.0
                for _ in range(OCTAVES):
                    n = snoise3(nx * frequency, ny * frequency, nz * frequency)
                    value += (1.0 - abs(n)) * amplitude
                    amplitude *= 0.5
                    frequency *= 2.0
                data[x, y, z] = value
    return data

def generate_worley():
    NUM_FEATURE_POINTS = 500
    feature_points = np.random.rand(NUM_FEATURE_POINTS, 3) * SIZE
    tree = cKDTree(feature_points)

    data = np.zeros((SIZE, SIZE, SIZE), dtype=np.float32)
    for z in range(SIZE):
        for y in range(SIZE):
            for x in range(SIZE):
                dist, _ = tree.query([x, y, z], k=1)
                data[x, y, z] = dist / SIZE
    return data

print("Generating Simplex...")
simplex = generate_simplex()
save_bin(simplex, os.path.join(OUTPUT_DIR, "simplex.bin"))

print("Generating FBM...")
fbm = generate_fbm()
save_bin(fbm, os.path.join(OUTPUT_DIR, "fbm.bin"))

print("Generating Ridged...")
ridged = generate_ridged()
save_bin(ridged, os.path.join(OUTPUT_DIR, "ridged.bin"))

print("Generating Worley...")
worley = generate_worley()
save_bin(worley, os.path.join(OUTPUT_DIR, "worley.bin"))

print("Done! 🎉")
