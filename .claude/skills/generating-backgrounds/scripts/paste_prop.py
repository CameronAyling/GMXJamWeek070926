#!/usr/bin/env python3
"""Paste a transparent-background prop onto a background, standing on the ground line.

usage: paste_prop.py BASE.png PROP.png OUT.png [--x 0.5] [--height 0.5] [--ground 0.73] [--no-shadow]
--x is the prop's centre as a fraction of the width (0.5 = over the wrap seam of a rolled image),
--height its height as a fraction of the background's height. The prop's own transparent margin is
trimmed first, so `--height` is the visible object. A soft ground shadow is drawn under it."""
import argparse
from PIL import Image, ImageDraw, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("prop"); ap.add_argument("out")
ap.add_argument("--x", type=float, default=0.5)
ap.add_argument("--height", type=float, default=0.5)
ap.add_argument("--ground", type=float, default=0.73)
ap.add_argument("--no-shadow", action="store_true")
a = ap.parse_args()

base = Image.open(a.base).convert("RGBA")
W, H = base.size
prop = Image.open(a.prop).convert("RGBA")
bbox = prop.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
if bbox is None:
    raise SystemExit("prop has no opaque pixels; was it generated with a transparent background?")
prop = prop.crop(bbox)
ph = round(H * a.height); pw = round(prop.width * ph / prop.height)
prop = prop.resize((pw, ph), Image.LANCZOS)
cx = round(W * a.x); ground = round(H * a.ground)
x0, y0 = cx - pw // 2, ground - ph

if not a.no_shadow:
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.ellipse((x0 + pw * 0.05, ground - ph * 0.04, x0 + pw * 0.95, ground + ph * 0.04), fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(max(2, pw // 40)))
    base.alpha_composite(sh)

# Wrap around the edges so a prop near x=0 still tiles.
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for dx in (-W, 0, W):
    layer.paste(prop, (x0 + dx, y0), prop)
base.alpha_composite(layer)
base.convert("RGB").save(a.out)
print(f"WROTE {a.out} (prop {pw}x{ph} at x={cx}, base on the ground line {ground})")
