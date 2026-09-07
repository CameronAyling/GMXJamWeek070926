#!/usr/bin/env python3
"""Fit a generated background to the room: crop where the wrap edges match best, scale to WxH, measure the seam, optionally label it.

usage: fit_background.py IN.png OUT.png [--size 1600x900] [--label "REPLACE ME"] [--no-tile-crop] [--max-crop 0.18]
       fit_background.py --crop-only IN.png OUT.png   # the seam-matched crop at source resolution
       fit_background.py --roll IN.png OUT.png      # shift by half the width (edges meet in the middle)
       fit_background.py --unroll IN.png OUT.png    # shift back
Prints `SEAM <ratio>`: the mean colour step across the wrap edge divided by the mean step between
ordinary neighbouring columns. ~1 tiles invisibly; above ~3 the seam will show when the image repeats
(the driver then runs the seam-fix pass). Also prints `GROUND <y>` — the ground line's row in OUT,
from where the template put it (73% of the height)."""
import argparse, sys
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--size", default="1600x900")
ap.add_argument("--label")
ap.add_argument("--label-y", type=float, default=0.62, help="label centre as a fraction of the height (on the ground, so it is in view when the backdrop is drawn 2x with the view at the bottom)")
ap.add_argument("--roll", action="store_true")
ap.add_argument("--unroll", action="store_true")
ap.add_argument("--ground", type=float, default=0.73, help="ground line as a fraction of the height")
ap.add_argument("--no-tile-crop", action="store_true", help="plain centre cover-crop instead of the seam-matched crop")
ap.add_argument("--max-crop", type=float, default=0.18, help="how much of the width the seam-matched crop may give up")
ap.add_argument("--plain", type=float, default=0.05, help="plain run to keep at each edge; the rest is trimmed")
ap.add_argument("--crop-only", action="store_true", help="write the seam-matched crop at source resolution, no scaling")
a = ap.parse_args()

im = Image.open(a.src)
im = im.convert("RGBA") if im.mode in ("RGBA", "LA", "P") and "A" in im.getbands() or im.mode == "RGBA" else im.convert("RGB")
W, H = im.size
if a.roll or a.unroll:
    # Same operation both ways for an even width; both flags exist for readability.
    im = ImageChops.offset(im, W // 2 if a.roll else -(W // 2), 0)
    im.save(a.out); print(f"WROTE {a.out} ({'rolled' if a.roll else 'unrolled'} by {W // 2})"); sys.exit(0)

tw, th = (int(v) for v in a.size.lower().split("x"))

def band_step(img, x1, x2, w=3):
    d = ImageChops.difference(img.crop((x1, 0, x1 + w, img.height)), img.crop((x2, 0, x2 + w, img.height)))
    return sum(ImageStat.Stat(d).mean) / 3

# Tile crop: the prompt makes the model draw the same object at both edges, which
# tiles as two of them side by side. Pick the crop window whose edge columns match
# best -- through the middle of that object -- giving up at most `a.max_crop` of the
# width; a narrower window costs a little so a clean full-width edge still wins.
sw = 480; small = im.convert("RGB").resize((sw, max(1, round(H * sw / W))), Image.LANCZOS)
inner = sum(band_step(small, x, x + 1) for x in range(0, sw - 4, 4)) / len(range(0, sw - 4, 4)) or 1e-6
best = (band_step(small, sw - 3, 0) / inner, 0, sw)
if not a.no_tile_crop:
    for wc in range(sw, int(sw * (1 - a.max_crop)), -1):
        for x0 in range(0, sw - wc + 1):
            r = band_step(small, x0 + wc - 3, x0) / inner + 4 * (1 - wc / sw)
            if r < best[0]:
                best = (r, x0, wc)
_, sx0, swc = best
cx0 = round(sx0 * W / sw); cw = W if swc == sw else round(swc * W / sw)
im = im.crop((cx0, 0, cx0 + cw, H))

# The prompt asks for a plain strip at each edge; the model tends to make it wide.
# Trim each side's plain run down to `a.plain` of the width (it lands around the
# seam once rolled, so the two runs add up).
def plain_run(img, xs):
    g = img.convert("L"); gh = g.height
    def stat(x):
        st = ImageStat.Stat(g.crop((x, 0, x + 1, gh))); return st.mean[0], st.stddev[0]
    m0, s0 = stat(xs[0]); k = 0
    for x in xs:
        m, s = stat(x)
        if abs(m - m0) < 10 and s < max(18, s0 * 1.5):
            k += 1
        else:
            break
    return k
if not a.no_tile_crop:
    g = im.convert("RGB").resize((512, max(1, round(H * 512 / cw))), Image.LANCZOS)
    left = plain_run(g, range(g.width)) / g.width; right = plain_run(g, range(g.width - 1, -1, -1)) / g.width
    tl = max(0.0, left - a.plain); tr = max(0.0, right - a.plain)
    room = max(0.0, a.max_crop - (1 - cw / W))
    if tl + tr > room:
        f = room / (tl + tr); tl *= f; tr *= f
    if tl + tr > 0.005:
        x0 = round(cw * tl); x1 = cw - round(cw * tr)
        im = im.crop((x0, 0, x1, H)); cx0 += x0; cw = x1 - x0
        print(f"TRIM plain edges {left:.0%}/{right:.0%} -> {a.plain:.0%} each")
print(f"CROP {cx0} {cw} ({cw / W:.0%} of the width)")
if a.crop_only:
    im.save(a.out); print(f"WROTE {a.out} ({cw}x{H})"); sys.exit(0)

# Scale to the target width; the crop only ever narrows, so the height covers. Trim
# rows keeping the ground line at the same fraction.
s = tw / cw
im = im.resize((tw, max(th, round(H * s))), Image.LANCZOS)
y0 = min(max(0, round(a.ground * im.height - a.ground * th)), im.height - th)
im = im.crop((0, y0, tw, y0 + th))

# Seam: colour step across the wrap edge vs the typical step between adjacent columns.
rgb = im.convert("RGB")
def col_step(x1, x2):
    d = ImageChops.difference(rgb.crop((x1, 0, x1 + 1, th)), rgb.crop((x2, 0, x2 + 1, th)))
    return sum(ImageStat.Stat(d).mean) / 3
wrap = col_step(tw - 1, 0)
inner = sum(col_step(x, x + 1) for x in range(0, tw - 1, max(1, tw // 200))) / len(range(0, tw - 1, max(1, tw // 200)))
ratio = wrap / max(inner, 1e-6)

if a.label:
    im = im.convert("RGBA") if im.mode != "RGBA" else im
    d = ImageDraw.Draw(im, "RGBA")
    size = max(24, tw // 16)
    font = None
    for f in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            font = ImageFont.truetype(f, size); break
        except OSError:
            pass
    font = font or ImageFont.load_default()
    box = d.textbbox((0, 0), a.label, font=font)
    lw, lh = box[2] - box[0], box[3] - box[1]
    cx, cy = tw // 2, int(th * a.label_y)
    d.rectangle((cx - lw // 2 - 24, cy - lh // 2 - 18, cx + lw // 2 + 24, cy + lh // 2 + 18), fill=(0, 0, 0, 110))
    d.text((cx - lw // 2 - box[0], cy - lh // 2 - box[1]), a.label, font=font, fill=(255, 255, 255, 230))

im.save(a.out)
print(f"WROTE {a.out} ({tw}x{th})")
print(f"SEAM {ratio:.2f}")
print(f"GROUND {int(th * a.ground)}")
