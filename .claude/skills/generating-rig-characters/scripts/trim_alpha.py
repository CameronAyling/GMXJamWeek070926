#!/usr/bin/env python3
"""Harden a generation's alpha and crop to its opaque bounds: trim_alpha.py IN.png OUT.png"""
import sys
from PIL import Image

im = Image.open(sys.argv[1]).convert("RGBA")
a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
im.putalpha(a)
bb = a.getbbox()
if bb is None:
    raise SystemExit("the generation has no opaque pixels")
im.crop(bb).save(sys.argv[2])
print(f"item {bb[2] - bb[0]}x{bb[3] - bb[1]} px")
