#!/usr/bin/env python3
"""Generate one game-object sprite on Replicate (openai/gpt-image-2) on a transparent background.

usage: gen_sprite.py --subject "a four-pointed steel shuriken" --style TEXT --out OUT.png
       [--inspiration IMG] [--quality low] [--size 1024x1024] [--model openai/gpt-image-2]
Writes OUT.png (RGBA) and OUT.prompt.txt."""
import argparse, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from replicate_api import fetch, predict, upload  # noqa: E402

ASSETS = os.path.join(os.path.dirname(HERE), "assets")
ap = argparse.ArgumentParser()
ap.add_argument("--subject", required=True)
ap.add_argument("--style", required=True)
ap.add_argument("--inspiration", help="reference image to copy the look from")
ap.add_argument("--out", required=True)
ap.add_argument("--quality", default="low", choices=["low", "medium", "high"])
ap.add_argument("--size", default="1024x1024", help="gpt-image-2 aspect_ratio / size")
ap.add_argument("--model", default="openai/gpt-image-2")
a = ap.parse_args()

prompt = open(os.path.join(ASSETS, "prompt-sprite.txt")).read().strip()
prompt = prompt.replace("{SUBJECT}", a.subject.strip()).replace("{STYLE}", a.style.strip())
if a.inspiration:
    prompt += "\nThe attached image is a style reference: copy its look, materials and colours; not its subject or composition."
prompt = "\n".join(line for line in prompt.splitlines() if line.strip())

t0 = time.time()
inp = {"prompt": prompt, "quality": a.quality, "background": "transparent", "output_format": "png",
       "aspect_ratio": a.size}
if a.inspiration:
    inp["input_images"] = [upload(a.inspiration)]
d = predict(a.model, inp)
out = d["output"] if isinstance(d["output"], str) else d["output"][0]
open(a.out, "wb").write(fetch(out))
open(a.out + ".prompt.txt", "w").write(prompt + "\n")
print(f"WROTE {a.out}  ({a.model} {a.quality}, id {d['id']}, {time.time() - t0:.0f}s)")
