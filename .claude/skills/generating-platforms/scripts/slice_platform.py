#!/usr/bin/env python3
"""Turn a painted platform into a three-slice sprite: trim it, find the pair of columns in its
middle that match best (the repeating centre runs between them; the caps are what is left
either side), optionally scale it, and write a preview of it at three widths.

usage: slice_platform.py IN.png OUT.png [--height PX] [--preview PREVIEW.png]
Prints `LEFT <px> RIGHT <px>` (the nine-slice guides for OUT), `SIZE <w>x<h>` and
`SEAM <ratio>`: the centre's wrap step over an ordinary neighbouring-column step. ~1 repeats
invisibly; above ~3 the joins will show and the platform wants another generation."""
import argparse
from PIL import Image, ImageChops

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--height", type=int, help="scale the sprite to this height in px")
ap.add_argument("--preview")
ap.add_argument("--min-tile", type=float, default=0.12, help="the centre's least width, as a fraction of the whole")
a = ap.parse_args()

im = Image.open(a.inp).convert("RGBA")
# Firm pixels only: a painted glow or haze around the platform is not the platform.
bb = im.getchannel("A").point(lambda v: 255 if v > 96 else 0).getbbox()
if bb is None:
    raise SystemExit("the image is fully transparent")
im = im.crop(bb)
W, H = im.size
# Premultiplied, so transparent pixels compare as transparent, not as their hidden colour;
# 48 rows is plenty to tell columns apart and keeps the search quick.
sig = im.convert("RGBa").resize((W, 48), Image.BOX)


def col_diffs(shift):
    """Per column x: the mean difference between column x and column x + shift."""
    d = ImageChops.difference(sig.crop((0, 0, W - shift, 48)), sig.crop((shift, 0, W, 48)))
    row = d.convert("L").resize((W - shift, 1), Image.BOX)   # a box filter: the column means
    return list(row.getdata())


lo, hi = int(W * 0.25), int(W * 0.75)
min_tile = max(16, int(W * a.min_tile))
best = None
for s in range(min_tile, hi - lo):
    diffs = col_diffs(s)
    # A wider centre repeats less often; a small preference for it breaks ties.
    weight = 1.0 / (1.0 + 0.3 * s / W)
    for x1 in range(lo, hi - s):
        score = diffs[x1] * weight
        if best is None or score < best[0]:
            best = (score, x1, x1 + s, diffs[x1])
_, x1, x2, d = best
one = col_diffs(1)
neigh = sum(one[lo:hi - 1]) / max(1, hi - 1 - lo)
seam = d / max(neigh, 1e-6)

scale = 1.0
if a.height:
    scale = a.height / H
    im = im.resize((max(1, round(W * scale)), a.height), Image.LANCZOS)
left, right = round(x1 * scale), round((W - x2) * scale)
im.save(a.out)
print(f"LEFT {left} RIGHT {right}")
print(f"SIZE {im.width}x{im.height}")
print(f"SEAM {seam:.2f}")

if a.preview:
    w, h = im.size
    capl, capr = im.crop((0, 0, left, h)), im.crop((w - right, 0, w, h))
    tile = im.crop((left, 0, w - right, h))

    def build(width):
        out = Image.new("RGBA", (width, h), (0, 0, 0, 0))
        out.paste(capl, (0, 0))
        x = left
        while x < width - right:
            part = tile.crop((0, 0, min(tile.width, width - right - x), h))
            out.paste(part, (x, 0))
            x += tile.width
        out.paste(capr, (width - right, 0))
        return out

    widths = [max(left + right + tile.width // 2, round(w * 0.6)), w, round(w * 2.5)]
    gap = 16
    pv = Image.new("RGBA", (max(widths) + 2 * gap, (h + gap) * len(widths) + gap), (70, 70, 70, 255))
    y = gap
    for wd in widths:
        b = build(wd)
        pv.paste(b, (gap, y), b)
        y += h + gap
    pv.save(a.preview)
    print(f"WROTE {a.preview}")
