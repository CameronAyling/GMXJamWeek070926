"""Re-align the frames of sprites/Spr_Robot_Was_Wings so the wings pivot in place.

    python tools/align_wasp_wings.py        (needs Pillow)

The three flap frames were each exported trimmed to their own content, so they
came out at different sizes (162x630, 289x633, 144x588). With a single shared
"centre" origin that means the wing root lands somewhere different every frame,
and the whole assembly jitters around instead of flapping about a fixed hinge.

Fix: paste each frame onto one shared canvas, shifted so its PIVOT — the point
midway between the two wing-root bolts, i.e. where the wings bolt to the body —
sits at the exact centre of the canvas. Then the sprite's "centre" origin is the
pivot for all three frames, and the wings sweep about a point that never moves.

PIVOTS were read off the art by eye (the round hinge bolt in each wing cluster);
a few pixels of slack here is sub-pixel once the sprite is drawn at game size.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "sprites", "Spr_Robot_Was_Wings")

# (pivot_x, pivot_y) per frame, in that frame's own pixels.
PIVOTS = [
    (73, 297),   # frame_000 — wings spread
    (145, 292),  # frame_001 — motion-blur smear
    (50, 286),   # frame_002 — wings gathered
]


def main():
    frames = [Image.open(os.path.join(DIR, f"frame_{i:03d}.png")).convert("RGBA")
              for i in range(len(PIVOTS))]

    # Canvas centred on the pivot: big enough that every frame clears its pivot
    # on all four sides, then doubled so the pivot is the exact middle.
    left = max(px for (px, _), _ in ((p, f) for p, f in zip(PIVOTS, frames)))
    right = max(f.size[0] - px for (px, _), f in zip(PIVOTS, frames))
    top = max(py for (_, py), _ in zip(PIVOTS, frames))
    bottom = max(f.size[1] - py for (_, py), f in zip(PIVOTS, frames))

    half_w = max(left, right)
    half_h = max(top, bottom)
    cw, ch = half_w * 2, half_h * 2
    cx, cy = half_w, half_h

    for i, (f, (px, py)) in enumerate(zip(frames, PIVOTS)):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(f, (cx - px, cy - py), f)
        canvas.save(os.path.join(DIR, f"frame_{i:03d}.png"))

    print(f"aligned {len(frames)} frames onto {cw}x{ch}, pivot (centre) at ({cx},{cy})")


main()
