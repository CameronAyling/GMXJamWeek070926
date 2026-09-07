#!/usr/bin/env python3
"""Add an attachment (a hat, a glove, a shield...) to a rig: work out where it sits in
atlas space from the rig's bind pose, append the `[[attachment]]` to rig.toml, put it
into draw_order, and write a preview of the atlas with it in place.

usage: attach.py --project DIR --rig NAME --name hat --sprite spr_rig_hat --bone head
                 [--anchor end|start|mid] [--size 0.25] [--offset DX,DY] [--angle DEG]
                 [--behind CHAIN | --after CHAIN] [--preview OUT.png]
--bone     head, neck, hips, left_hand, right_hand, left_foot, right_foot, or a bone name
--anchor   which point of the bone the sprite's centre goes on (default: end for head/hands/feet)
--size     the sprite's height as a fraction of the character's height in the atlas; default: the bone's
           own length (a hat 1.4x the head bone; hand items 1.3x the hand bone)
--offset   nudge, as fractions of the character's height, +y down
--angle    rotation at bind pose, degrees (0 = the sprite as drawn, upright)
--behind   draw just behind that chain (default: just in front of the bone's own chain)"""
import argparse, json, math, os, re
from PIL import Image

ALIASES = {
    "head": "mixamorig:Head", "neck": "mixamorig:Neck", "hips": "mixamorig:Hips",
    "left_hand": "mixamorig:LeftHand", "right_hand": "mixamorig:RightHand",
    "left_foot": "mixamorig:LeftFoot", "right_foot": "mixamorig:RightFoot",
}

ap = argparse.ArgumentParser()
ap.add_argument("--project", required=True); ap.add_argument("--rig", required=True)
ap.add_argument("--name", required=True); ap.add_argument("--sprite", required=True)
ap.add_argument("--bone", required=True)
ap.add_argument("--anchor", choices=["end", "start", "mid"], default="end")
ap.add_argument("--size", type=float)
ap.add_argument("--offset", default="0,0")
ap.add_argument("--angle", type=float, default=0.0)
ap.add_argument("--behind"); ap.add_argument("--after")
ap.add_argument("--preview")
a = ap.parse_args()

rig_dir = os.path.join(a.project, "rigs", a.rig)
doc = json.load(open(os.path.join(rig_dir, "rig.json")))
bone_name = ALIASES.get(a.bone, a.bone)

# Bind pose in atlas space: each chain's bones follow on from its root.
bones = {}; ys = []; chain_of = {}
for c in doc["chains"]:
    x, y = c["root"]; ang = 0.0
    for name, b in zip(c["bones"], c["pose"]):
        ang += b["angle"]; r = math.radians(ang)
        ex, ey = x + math.cos(r) * b["length"], y + math.sin(r) * b["length"]
        bones[name] = {"start": (x, y), "end": (ex, ey), "angle": ang}
        chain_of[name] = c["name"]; ys += [y, ey]
        x, y = ex, ey
if bone_name not in bones:
    raise SystemExit(f"no bone {bone_name!r}; the rig has: {', '.join(bones)}")
b = bones[bone_name]
char_h = max(ys) - min(ys)
anchor = {"end": b["end"], "start": b["start"],
          "mid": ((b["start"][0] + b["end"][0]) / 2, (b["start"][1] + b["end"][1]) / 2)}[a.anchor]
dx, dy = (float(v) for v in a.offset.split(","))
at = (round(anchor[0] + dx * char_h, 1), round(anchor[1] + dy * char_h, 1))

frame = os.path.join(a.project, "sprites", a.sprite, "frame_000.png")
im = Image.open(frame).convert("RGBA")
bb = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
sprite_h = bb[3] - bb[1]
bone_len = math.dist(b["start"], b["end"])
size = a.size if a.size else (1.3 if "Hand" in bone_name else 1.4 if "Head" in bone_name else 1.0) * bone_len / char_h
scale = round(size * char_h / sprite_h, 4)
# 0 = the sprite upright at bind pose; the runtime adds the bone's motion on top.
angle = round(a.angle, 2)

toml_path = os.path.join(rig_dir, "rig.toml")
toml = open(toml_path).read()
if re.search(rf'^\s*name = "{re.escape(a.name)}"', toml, re.M):
    raise SystemExit(f"rig.toml already has an attachment or entry named {a.name!r}")
m = re.search(r'^draw_order = \[(.*?)\]', toml, re.M | re.S)
if not m:
    raise SystemExit("rig.toml has no draw_order")
order = [s.strip().strip('"') for s in m.group(1).split(",") if s.strip()]
ref = a.behind or a.after or chain_of[bone_name]
if ref not in order:
    raise SystemExit(f"{ref!r} is not in draw_order {order}")
i = order.index(ref)
order.insert(i if a.behind else i + 1, a.name)
toml = toml[:m.start()] + "draw_order = [" + ", ".join(f'"{s}"' for s in order) + "]" + toml[m.end():]
toml = toml.rstrip("\n") + f'''

[[attachment]]
name = "{a.name}"
sprite = "{a.sprite}"
bone = "{bone_name}"
at = [{at[0]}, {at[1]}]
angle = {angle}
scale = {scale}
visible = true
'''
open(toml_path, "w").write(toml)
print(f"ATTACHED {a.name}: {bone_name} {a.anchor} -> at {at}, height {size:.2f} of the character, scale {scale}, angle {angle}; draw_order {order}")

if a.preview:
    atlas_name = re.search(r'^atlas = "([^"]+)"', toml, re.M).group(1)
    atlas = Image.open(os.path.join(a.project, "sprites", atlas_name, "frame_000.png")).convert("RGBA")
    item = im.crop(bb)
    item = item.resize((max(1, round(item.width * scale)), max(1, round(item.height * scale))), Image.LANCZOS)
    layer = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    layer.paste(item, (round(at[0] - item.width / 2), round(at[1] - item.height / 2)), item)
    out = Image.alpha_composite(Image.alpha_composite(Image.new("RGBA", atlas.size, (60, 60, 60, 255)), atlas), layer)
    out.save(a.preview); print(f"WROTE {a.preview}")
