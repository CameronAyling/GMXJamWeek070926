#!/usr/bin/env python3
"""Paint one wide platform on a transparent background on Replicate (openai/gpt-image-2).

usage: gen_platform.py --style TEXT --out OUT.png [--reference SCENE.png] [--quality low] [--model openai/gpt-image-2]
--reference is an image of the scene it will stand in (the background sprite, say); the platform
is painted to match its palette and lighting."""
import argparse, io, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from replicate_api import fetch, predict, upload

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "assets")

ap = argparse.ArgumentParser()
ap.add_argument("--style", required=True)
ap.add_argument("--reference")
ap.add_argument("--out", required=True)
ap.add_argument("--quality", default="low", choices=["low", "medium", "high"])
ap.add_argument("--aspect", default="2048x1152")
ap.add_argument("--model", default="openai/gpt-image-2")
a = ap.parse_args()

prompt = open(os.path.join(ASSETS, "prompt-platform.txt")).read().strip().replace("{STYLE}", a.style.strip())
inp = {"prompt": prompt, "quality": a.quality, "output_format": "png", "aspect_ratio": a.aspect,
       "background": "transparent"}
if a.reference:
    inp["prompt"] = ("The attached image is the scene this platform will be placed in: match its style, palette, "
                     "line quality and lighting exactly. ") + prompt
    inp["input_images"] = [upload(a.reference)]
d = predict(a.model, inp)
out = d["output"] if isinstance(d["output"], str) else d["output"][0]
im = Image.open(io.BytesIO(fetch(out))).convert("RGBA")
im.save(a.out)
print(f"WROTE {a.out} {im.width}x{im.height}")
