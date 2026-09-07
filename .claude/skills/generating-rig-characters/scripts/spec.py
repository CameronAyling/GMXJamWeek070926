#!/usr/bin/env python3
"""Write a character's style/look specification from a generated sheet (a vision model on Replicate).

usage: spec.py SHEET.png OUT.txt [--model openai/gpt-5]
The specification carries the character from the iso_se sheet to the iso_ne one (gen_atlas.py --spec)."""
import argparse, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from replicate_api import predict, upload  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("sheet"); ap.add_argument("out")
ap.add_argument("--model", default="openai/gpt-5")
a = ap.parse_args()
prompt = open(os.path.join(os.path.dirname(HERE), "assets", "spec-request.txt")).read().strip()
t0 = time.time()
d = predict(a.model, {"prompt": prompt, "image_input": [upload(a.sheet)]})
text = d["output"]
text = "".join(text) if isinstance(text, list) else str(text)
open(a.out, "w").write(text.strip() + "\n")
print(f"WROTE {a.out}  ({a.model}, {len(text.split())} words, {time.time() - t0:.0f}s)")
