#!/usr/bin/env python3
"""Clean a generated sprite: hard alpha, crop to the opaque bounds (+pad), scale to a target height.

usage: fit_sprite.py IN.png OUT.png [--height 128] [--pad 4] [--threshold 96]
Prints `SIZE WxH` and `PARTS n` (opaque components larger than 2% of the pixels; 1 is what you want,
more means the model drew extra pieces or the backdrop came back opaque)."""
import argparse
from collections import deque
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--height", type=int, default=128, help="output height in px (width follows); 0 keeps the size")
ap.add_argument("--pad", type=int, default=4)
ap.add_argument("--threshold", type=int, default=96)
a = ap.parse_args()

im = Image.open(a.src).convert("RGBA")
W, H = im.size
px = im.load()
# Hard alpha, so the sprite has clean edges and a real bounding box.
alpha = bytearray(W * H)
for y in range(H):
    for x in range(W):
        r, g, b, al = px[x, y]
        if al >= a.threshold:
            alpha[y * W + x] = 1
        else:
            px[x, y] = (r, g, b, 0)
# Count parts, so a fused/extra piece is reported rather than shipped blind.
seen = bytearray(W * H); parts = 0; total = sum(alpha)
for i0 in range(W * H):
    if not alpha[i0] or seen[i0]:
        continue
    q = deque([i0]); seen[i0] = 1; n = 0
    while q:
        i = q.popleft(); n += 1; x, y = i % W, i // W
        for u, v in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= u < W and 0 <= v < H:
                j = v * W + u
                if alpha[j] and not seen[j]:
                    seen[j] = 1; q.append(j)
    if n >= 0.02 * max(total, 1):
        parts += 1
box = im.getbbox()
if box is None:
    raise SystemExit("the image is fully transparent")
x0, y0, x1, y1 = box
im = im.crop((max(0, x0 - a.pad), max(0, y0 - a.pad), min(W, x1 + a.pad), min(H, y1 + a.pad)))
if a.height > 0 and im.height != a.height:
    im = im.resize((max(1, round(im.width * a.height / im.height)), a.height), Image.LANCZOS)
im.save(a.out)
print(f"WROTE {a.out}")
print(f"SIZE {im.width}x{im.height}")
print(f"PARTS {parts}")
