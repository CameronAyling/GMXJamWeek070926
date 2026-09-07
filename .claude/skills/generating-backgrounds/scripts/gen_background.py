#!/usr/bin/env python3
"""Generate a tileable side-scroller background on Replicate (openai/gpt-image-2).

usage: gen_background.py --style TEXT --out OUT.png [--quality low] [--aspect 2048x1152] [--model openai/gpt-image-2]
       gen_background.py --fix-seam IN.png --out OUT.png [--quality low]
       gen_background.py --prop "a parked delivery van" --style TEXT --out PROP.png [--aspect 1536x1024]
--style paints a fresh background over the skill's 16:9 ground-line template (assets/bg-template.png).
--fix-seam takes an already-rolled image (its former edges now meet in the middle), sends the
model only a full-height 2:3 strip around that seam to repaint, and composites the result back
with a feathered mask, so everything outside the strip stays pixel-identical; roll it back
afterward (fit_background.py does both).
--prop paints one object in the style on a transparent background, for paste_prop.py to stand on the
ground line -- over the seam, or anywhere a plain stretch needs something."""
import argparse, io, os, sys, time

from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from replicate_api import fetch, predict, upload  # noqa: E402

ASSETS = os.path.join(os.path.dirname(HERE), "assets")
ap = argparse.ArgumentParser()
ap.add_argument("--style")
ap.add_argument("--fix-seam", metavar="IN.png")
ap.add_argument("--prop", metavar="TEXT", help="one object on a transparent background, in --style")
ap.add_argument("--place", metavar="PROP.png", help="--fix-seam: also stand this transparent-background object on the ground at the seam")
ap.add_argument("--transparent", action="store_true", help="--style/--fix-seam: keep a transparent background (a parallax layer)")
ap.add_argument("--px-per-m", type=float, help="scene scale in the fitted output (pixels per metre); --size-h gives that output height")
ap.add_argument("--size-h", type=int, default=900, help="the fitted output height --px-per-m refers to")
ap.add_argument("--place-metres", type=float, help="--place: the prop's real height, sized by --px-per-m")
ap.add_argument("--out", required=True)
ap.add_argument("--quality", default="low", choices=["low", "medium", "high"])
ap.add_argument("--aspect", default="2048x1152", help="gpt-image-2 aspect_ratio / size; 16:9 sizes only make sense here")
ap.add_argument("--model", default="openai/gpt-image-2")
ap.add_argument("--keep", type=float, default=0.5, help="--fix-seam: fraction of the strip taken from the repaint as-is; the rest feathers back to the original")
a = ap.parse_args()

background = "opaque"
if a.prop:
    if not a.style:
        sys.exit("--prop needs --style TEXT")
    prompt = (f"A single {a.prop.strip()}, and nothing else, isolated on a fully transparent background. "
              "An ordinary, typical example of it -- not a landmark, not unique, the kind that could appear "
              "several times along a street. "
              f"Style: {a.style.strip()}. Seen straight from the side at street level, no perspective, standing "
              "on flat ground with its base at the very bottom of the image. The whole object is visible and "
              "uncut, filling the frame. Lit exactly as it would be inside a scene in that style -- same time "
              "of day, same light sources and colour cast. No ground, no floor, no cast "
              "shadow on the ground, no text, no people.")
    images = []
    background = "transparent"
elif a.fix_seam:
    mode = "RGBA" if a.transparent else "RGB"
    background = "transparent" if a.transparent else "opaque"
    src = Image.open(a.fix_seam).convert(mode)
    W, H = src.size
    sw = round(H * 2 / 3); sx = (W - sw) // 2
    strip = src.crop((sx, 0, sx + sw, H))
    strip.save(a.out + ".strip.png")
    prompt = ("This is the middle part of a horizontally tiling side-scroller background. A hard vertical seam "
              "runs exactly down the centre where two edges meet. Repaint the area around that seam so the two "
              "sides join seamlessly: continue the ground, sidewalk, walls, sky and lighting straight across at "
              "the same heights and colours. If the same object appears twice side by side near the centre "
              "(two lamp posts, two doors, two trees, two columns), merge them into ONE object at the centre and "
              "paint the other away. Keep the left and right quarters of the image exactly as they are. Same "
              "style, same size. No characters, no text.")
    images = [upload(a.out + ".strip.png")]
    if a.place:
        prompt = ("The first image is the middle part of a horizontally tiling side-scroller background; a hard "
                  "vertical seam runs exactly down its centre where two edges meet. The second image is an object "
                  "on a transparent background. Paint that object into the first image, standing ON the ground "
                  "exactly at the centre, its base resting on the walkable ground surface (the pavement, floor or "
                  "path -- not floating above it, not sunk into it), at a natural size, with a soft contact shadow "
                  "and lighting matching the scene. "
                  + (f"Its height must be about {a.place_metres * a.px_per_m / a.size_h:.0%} of the image height. " if a.place_metres and a.px_per_m else "")
                  + "Behind and around it, repaint the seam so the two sides join "
                  "seamlessly: continue the ground, walls, sky and lighting straight across at the same heights. "
                  "Keep the left and right quarters of the image exactly as they are. Same style, same size. "
                  "No characters, no text.")
        images.append(upload(a.place))
    a.aspect = "1024x1536"
else:
    if not a.style:
        sys.exit("--style TEXT is required (or --fix-seam IN.png)")
    prompt = open(os.path.join(ASSETS, "prompt-background.txt")).read().strip().replace("{STYLE}", a.style.strip())
    if a.px_per_m:
        person = 1.8 * a.px_per_m / a.size_h
        prompt += (f"\nScale: an adult standing on the ground line would be about {person:.0%} of the picture's height. "
                   "Draw doors, windows, storeys, vehicles and furniture to match that size.")
    images = [upload(os.path.join(ASSETS, "bg-template.png"))]
    if a.transparent:
        background = "transparent"
prompt = "\n".join(line for line in prompt.splitlines() if line.strip())

t0 = time.time()
def match_prop_height(edit, prop, base_frac):
    """Where the placed prop ended up: the prop image's best-matching scale in the edited strip, base on the ground."""
    from PIL import ImageStat
    e = edit.convert("RGB"); sw = 192; e = e.resize((sw, round(e.height * sw / e.width)), Image.LANCZOS); w, h = e.size
    bb = prop.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bb is None:
        return None
    p = prop.crop(bb); base = round(base_frac * h); best = (1e9, None)
    for ph in range(max(6, int(h * 0.12)), int(h * 0.95)):
        pw = max(1, round(p.width * ph / p.height))
        if pw > w:
            break
        ps = p.resize((pw, ph), Image.LANCZOS); mask = ps.getchannel("A").point(lambda v: 255 if v > 128 else 0); rgb = ps.convert("RGB")
        y0 = base - ph - 2
        if y0 < 0:
            continue
        for x0 in range(max(0, w // 2 - pw // 2 - w // 8), min(w - pw, w // 2 - pw // 2 + w // 8) + 1, 2):
            score = sum(ImageStat.Stat(ImageChops.difference(e.crop((x0, y0, x0 + pw, y0 + ph)), rgb), mask).mean) / 3
            if score < best[0]:
                best = (score, ph / h)
    return best[1]


inp = {"prompt": prompt, "quality": a.quality, "output_format": "png", "aspect_ratio": a.aspect,
       "background": background}
if images:
    inp["input_images"] = images
d = predict(a.model, inp)
out = d["output"] if isinstance(d["output"], str) else d["output"][0]
png = fetch(out)
if a.fix_seam:
    edited = Image.open(io.BytesIO(png)).convert(src.mode).resize((sw, H), Image.LANCZOS)
    edited.save(a.out + ".edit.png")
    # 255 across the kept centre, ramping to 0 at the strip's edges.
    ramp = (1 - a.keep) / 2 * sw
    row = [int(255 * min(1, min(x, sw - 1 - x) / ramp)) for x in range(sw)]
    mask = Image.new("L", (sw, 1)); mask.putdata(row); mask = mask.resize((sw, H))
    src.paste(Image.composite(edited, strip, mask), (sx, 0))
    src.save(a.out)
    if a.place:
        # The seam repaint changes a narrow vertical band; the placed prop changes a
        # wide one. The lowest wide-change row is the prop's base on the ground.
        diff = ImageChops.difference(strip, edited).convert("L").resize((sw // 4, H // 4))
        px = diff.load(); dw, dh = diff.size
        wide = [sum(1 for x in range(dw) if px[x, y] > 24) > 0.2 * dw for y in range(dh)]
        base = next((y for y in range(dh - 1, -1, -1) if wide[y]), None)
        top = next((y for y in range(dh) if wide[y]), None)
        if base is not None:
            base_frac = (base + 1) / dh
            print(f"PROPBASE {base_frac:.3f}")
            print(f"WALK {min(0.95, base_frac + 0.02):.3f}")
            hf = match_prop_height(edited, Image.open(a.place), base_frac)
            if hf:
                print(f"PROPHEIGHT {hf:.3f}")
else:
    open(a.out, "wb").write(png)
open(a.out + ".prompt.txt", "w").write(prompt + "\n")
print(f"WROTE {a.out}  ({a.model} {a.quality}, id {d['id']}, {time.time() - t0:.0f}s)")
