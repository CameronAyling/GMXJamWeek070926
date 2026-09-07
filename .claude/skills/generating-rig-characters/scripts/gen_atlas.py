#!/usr/bin/env python3
"""Generate a 5-part paper-doll sheet on Replicate (openai/gpt-image-2, quality=low) from a view's layout template.

usage: gen_atlas.py --view side|iso_se|iso_ne --out OUT.png (--style TEXT | --spec FILE) [--inspiration IMG]
       [--quality low] [--model openai/gpt-image-2]
       gen_atlas.py --item "a red tricorn hat" --reference ATLAS.png --out OUT.png   # an accessory in the atlas's style
side and iso_se take --style (free text); iso_ne takes --spec (the character specification written by spec.py
from the iso_se result), so both isometric sheets show the same character.
Writes OUT.png (RGBA) and OUT.prompt.txt."""
import argparse, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from replicate_api import fetch, predict, upload  # noqa: E402

ASSETS = os.path.join(os.path.dirname(HERE), "assets")
VIEWS = {"side": ("side-template.png", "prompt-side.txt"),
         "iso_se": ("iso-se-template.png", "prompt-iso-se.txt"),
         "iso_ne": ("iso-ne-template.png", "prompt-iso-ne.txt")}
ap = argparse.ArgumentParser()
ap.add_argument("--view", choices=sorted(VIEWS))
ap.add_argument("--item", help="an accessory to paint alone, in the style of --reference")
ap.add_argument("--reference", help="--item: the rig's atlas, the style and camera to match")
ap.add_argument("--side", choices=["far", "near"], help="--item: a hand item seen from the far arm's palm side or the near arm's back-of-hand side")
ap.add_argument("--style", help="character / style description (side, iso_se)")
ap.add_argument("--spec", help="character specification file (iso_ne)")
ap.add_argument("--inspiration", help="reference image whose outfit, colours and materials to follow")
ap.add_argument("--out", required=True)
ap.add_argument("--quality", default="low", choices=["low", "medium", "high"])
ap.add_argument("--model", default="openai/gpt-image-2")
a = ap.parse_args()

if a.item:
    if not a.reference:
        sys.exit("--item needs --reference ATLAS.png")
    prompt = (f"A single {a.item.strip()}, and nothing else, isolated on a fully transparent background. It is an "
              "accessory for the character in the first image, which is a paper-doll atlas: paint it in exactly that "
              "art style, line weight, colours and shading, from the same camera angle, oriented as it would be worn "
              "or held when the character stands upright, and sized to fit that character. No character, no body "
              "parts, no text, no shadow on the ground."
              + {"far": " It is worn or held by the FAR hand of the atlas (the left-most arm): show the side of it "
                        "that faces the viewer there, the palm side, thumb toward the front.",
                 "near": " It is worn or held by the NEAR hand of the atlas (the right-most arm): show the side of "
                         "it that faces the viewer there, the back-of-hand side.",
                 None: ""}[a.side])
    images = [upload(a.reference)]
    t0 = time.time()
    d = predict(a.model, {"prompt": prompt, "input_images": images, "quality": a.quality, "background": "transparent",
                          "output_format": "png", "aspect_ratio": "1024x1024"})
    out = d["output"] if isinstance(d["output"], str) else d["output"][0]
    open(a.out, "wb").write(fetch(out)); open(a.out + ".prompt.txt", "w").write(prompt + "\n")
    print(f"WROTE {a.out}  ({a.model} {a.quality}, item, id {d['id']}, {time.time() - t0:.0f}s)")
    sys.exit(0)
if not a.view:
    sys.exit("--view is required (or --item)")
template, prompt_file = VIEWS[a.view]
prompt = open(os.path.join(ASSETS, prompt_file)).read().strip()
if a.view == "iso_ne":
    if not a.spec:
        sys.exit("iso_ne needs --spec FILE (write one with spec.py from the iso_se sheet)")
    prompt = prompt.replace("{SPEC}", open(a.spec).read().strip())
else:
    if not a.style:
        sys.exit(f"{a.view} needs --style TEXT")
    insp = ("The second image is a style reference: it defines outfit, colours and materials only. It is from a "
            "different angle and must not influence the orientation or geometry of any part." if a.inspiration else "")
    prompt = prompt.replace("{INSPIRATION}", insp).replace("{STYLE}", a.style.strip())
prompt = "\n".join(line for line in prompt.splitlines() if line.strip())

t0 = time.time()
images = [upload(os.path.join(ASSETS, template))] + ([upload(a.inspiration)] if a.inspiration else [])
d = predict(a.model, {"prompt": prompt, "input_images": images, "quality": a.quality, "background": "transparent",
                      "output_format": "png"})
out = d["output"] if isinstance(d["output"], str) else d["output"][0]
open(a.out, "wb").write(fetch(out))
open(a.out + ".prompt.txt", "w").write(prompt + "\n")
print(f"WROTE {a.out}  ({a.model} {a.quality}, view {a.view}, id {d['id']}, {time.time() - t0:.0f}s)")
