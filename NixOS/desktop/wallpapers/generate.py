"""Reproducible, dependency-free Catppuccin Mocha night landscape."""
import math
from pathlib import Path
import random
import struct
import zlib

W, H = 3840, 2160
rng = random.Random(20261031)
# A quiet lavender horizon, with three overlapping mountain silhouettes.
ridges = []
for baseline, amplitude, color in [
    (0.58, 0.14, (69, 64, 95)),
    (0.72, 0.10, (49, 50, 68)),
    (0.87, 0.08, (24, 24, 37)),
]:
    phase = rng.random() * 6
    heights = [int(H * (baseline + amplitude * (
        math.sin(x / W * 8 + phase) * 0.6
        + math.sin(x / W * 21 + phase) * 0.25
        + math.sin(x / W * 41) * 0.15))) for x in range(W)]
    ridges.append((heights, color))
stars = {}
for _ in range(210):
    x, y = rng.randrange(W), rng.randrange(int(H * 0.43))
    stars[x, y] = rng.choice([(186, 194, 222), (205, 214, 244), (203, 166, 247)])
rows = []
for y in range(H):
    t = min(y / (H * 0.7), 1)
    sky = tuple(round(a + (b - a) * t) for a, b in zip((17, 17, 27), (67, 56, 83)))
    row = bytearray()
    for x in range(W):
        color = stars.get((x, y), sky)
        # Small warm moon; no external images or fonts.
        if (x - W * 0.76) ** 2 + (y - H * 0.25) ** 2 < (H * 0.035) ** 2:
            color = (245, 224, 220)
        for heights, mountain in ridges:
            if y >= heights[x]:
                color = mountain
        row.extend(color)
    rows.append(b"\x00" + row)

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")
Path(__file__).with_name("mocha-mountains.png").write_bytes(png)
