import numpy as np
from noise import pnoise3
from tqdm import tqdm


shape = (64, 64, 64) # Shape of the 3D volume
scale = 0.1 # Frequency of the noise
octaves = 4 # Number of noise layers
persistence = 0.5 # Amplitude multiplier
lacunarity = 2.0 # Frequency multiplier
seed = 0# Seed for the noise function



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

"""
# 3D Perlin-Noise Generator Dokumentation

## Funktionsweise
Der Script generiert ein 3D Perlin-Rauschen und speichert es in einer binären Datei. Die Hauptkomponenten sind:

- 64x64x64 3D-Volumen
- Skalierung (0.1) für glatteres Rauschen
- 4 Oktaven für mehrschichtige Rauschüberlagerung
- Persistence und Lacunarity für Amplituden- und Frequenzsteuerung

## Kachelbarkeit (Tiling)
Das generierte Volumen ist in allen drei Dimensionen kachelbar durch die Parameter:
```python
repeatx=shape[2]  # 64
repeaty=shape[1]  # 64
repeatz=shape[0]  # 64

Diese Parameter sorgen dafür, dass das Rauschen an den Grenzen nahtlos übergeht.
Nicht-kachelbares Verhalten
Ohne die repeat-Parameter erzeugt die Funktion ein kontinuierliches, nicht-wiederholendes Muster:
Keine übereinstimmenden Werte an den Grenzen
Sichtbare Übergänge beim Kacheln
Endloses, einzigartiges Muster im Raum
Abhängigkeiten
Benötigte Python-Pakete:
numpy
noise
tqdm

"""