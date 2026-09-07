#!/usr/bin/env python3
"""Clean a generated 5-part sheet into a rig atlas: hard alpha, exactly five parts, packed left-to-right.

usage: fix_sheet.py IN.png OUT.png [--order 4,3,2,1,0] [--gutter 28] [--min-area 0.02]
Also writes OUT.parts.json (size + per-part boxes).
Parts are the connected opaque components, sorted by centroid x. The rig convention is
LEFT ARM, LEFT LEG, TORSO+HEAD, RIGHT LEG, RIGHT ARM; --order re-orders the found parts
(indices into the x-sorted list) when the image drew them out of order."""
import argparse, json, sys
from collections import deque
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--order", help="comma list, e.g. 4,3,2,1,0 mirrors the sheet's part order")
ap.add_argument("--gutter", type=int, default=28)
ap.add_argument("--min-area", type=float, default=0.02, help="drop specks below this share of opaque pixels")
ap.add_argument("--threshold", type=int, default=128)
a = ap.parse_args()

im = Image.open(a.src).convert("RGBA")
W, H = im.size
px = im.load()
alpha = [1 if px[x, y][3] >= a.threshold else 0 for y in range(H) for x in range(W)]
seen = bytearray(W * H)
comps = []
for i0 in range(W * H):
    if not alpha[i0] or seen[i0]:
        continue
    q = deque([i0]); seen[i0] = 1; pts = []
    while q:
        i = q.popleft(); pts.append(i); x, y = i % W, i // W
        for u, v in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= u < W and 0 <= v < H:
                j = v * W + u
                if alpha[j] and not seen[j]:
                    seen[j] = 1; q.append(j)
    comps.append(pts)
total = sum(len(c) for c in comps)
parts = [c for c in comps if len(c) >= a.min_area * total]
specks = total - sum(len(c) for c in parts)
parts.sort(key=lambda c: sum(i % W for i in c) / len(c))
areas = [round(len(c) / total, 3) for c in parts]
if len(parts) != 5:
    sys.exit(f"expected 5 parts, found {len(parts)} (area shares {areas}, specks {specks / total:.3f}); "
             f"regenerate or fix the image by hand")
order = [int(s) for s in a.order.split(",")] if a.order else [0, 1, 2, 3, 4]
if sorted(order) != [0, 1, 2, 3, 4]:
    sys.exit(f"--order must be a permutation of 0..4, got {order}")

cells = []
for c in parts:
    xs = [i % W for i in c]; ys = [i // W for i in c]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cell = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0)); q = cell.load()
    for i in c:
        x, y = i % W, i // W; r, g, b, _ = px[x, y]; q[x - x0, y - y0] = (r, g, b, 255)
    cells.append((cell, y0))
cells = [cells[i] for i in order]
gy = min(y0 for _, y0 in cells)
x = a.gutter; placed = []
for cell, y0 in cells:
    placed.append((cell, x, y0 - gy + a.gutter)); x += cell.width + a.gutter
out = Image.new("RGBA", (x, max(py + c.height for c, _, py in placed) + a.gutter), (0, 0, 0, 0))
for cell, px_, py in placed:
    out.alpha_composite(cell, (px_, py))
out.save(a.out)
names = ["left_arm", "left_leg", "spine", "right_leg", "right_arm"]
json.dump({"width": out.width, "height": out.height, "source": a.src, "order": order,
           "parts": [{"chain": n, "x": px_, "y": py, "w": c.width, "h": c.height, "area_share": areas[order[k]]}
                     for k, ((c, px_, py), n) in enumerate(zip(placed, names))]},
          open(a.out.rsplit(".", 1)[0] + ".parts.json", "w"), indent=1)
print(f"WROTE {a.out} {out.size}  parts {areas} specks {specks / total:.3f}")
