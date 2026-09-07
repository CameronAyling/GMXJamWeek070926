#!/usr/bin/env python3
"""Draw a rig.json's chains (bones, roots, mesh wireframe) over its atlas for a visual check.
usage: overlay.py ATLAS.png RIG.json OUT.png"""
import json, math, sys
from PIL import Image, ImageDraw

atlas, rig, out = sys.argv[1:4]
im = Image.open(atlas).convert("RGBA")
bg = Image.new("RGBA", im.size, (38, 43, 49, 255)); bg.alpha_composite(im); im = bg
d = ImageDraw.Draw(im)
COL = {"spine": (255, 220, 80), "left_arm": (90, 200, 255), "right_arm": (40, 120, 255),
       "left_leg": (120, 255, 140), "right_leg": (40, 180, 80)}
for c in json.load(open(rig))["chains"]:
    col = COL.get(c["name"], (255, 255, 255))
    mesh = c.get("mesh") or {}
    V = mesh.get("vertices") or []
    for tri in mesh.get("triangles") or []:
        pts = [tuple(V[i][:2]) for i in tri]
        d.polygon(pts, outline=col + (70,))
    x, y = c["root"]; ang = 0.0
    for b in c["pose"]:
        ang += b["angle"]; r = math.radians(ang)
        tx, ty = x + math.cos(r) * b["length"], y + math.sin(r) * b["length"]
        d.line([(x, y), (tx, ty)], fill=col, width=3); d.ellipse([tx - 3, ty - 3, tx + 3, ty + 3], fill=col)
        x, y = tx, ty
    rx, ry = c["root"]; d.ellipse([rx - 6, ry - 6, rx + 6, ry + 6], outline=(255, 255, 255), width=2)
    d.text((rx + 8, ry - 14), c["name"], fill=col)
im.save(out); print(f"WROTE {out}")
