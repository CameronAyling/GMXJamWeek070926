"""Rebuild sprites/Spr_Bug_Wings_Flap from sprites/Spr_Bug_Wings_001.png.

    python tools/make_bug_wing_flap.py        (needs Pillow)

Spr_Bug_Wings_001.png is a painted wing pair, drawn twice and flipped. The
right wing of the top pose is the cleanest complete wing, so it gets isolated,
mirrored into a symmetric pair, and swung about its root to three top-down
stroke positions. Two pairs are built — a full-size forewing pair and a smaller
hindwing pair set back along the body — and the finished frames are turned 90
degrees anticlockwise and mirrored, so the bug faces left with its wings
sweeping back.

Everything below is authored in "upright" space: body axis vertical, head at
the bottom, wings splaying up. The final rotation is the last step.
Tune the constants below and re-run.
"""
import os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "sprites", "Spr_Bug_Wings_001.png")
DST = os.path.join(ROOT, "sprites", "Spr_Bug_Wings_Flap")

HINGE = (133, 437)          # where the source pair meets, in top-pose coords
LEAN = -16.98               # wing axis, degrees CCW from straight up
CANVAS = (1300, 1100)
FORE_ROOT_Y = 900.0         # forewing roots on the working canvas
MAX_DIM = 384               # longest side of the finished frame

ROOT_GAP = 45.0             # each wing root, sideways from the body axis
HIND_SCALE = 0.72           # hindwing size, relative to the forewings
HIND_SETBACK = 95.0         # hindwing roots, back along the body from the fore

# stroke positions: (sweep from the body axis in degrees, foreshortening)
DOWN = (74.0, 1.00)         # bottom of the downstroke, wings spread wide
UP = (26.0, 0.80)           # top of the upstroke, wings raised and together
SMEAR_STEPS = 15
GHOST_ALPHA = 0.05          # per-ghost opacity; four wings stack up fast
GHOST_BLUR = 5
SMEAR_BODY = 0.62           # the readable wing shape sitting in the streak

CX = CANVAS[0] / 2.0        # the body axis, and the mirror line


def to_premul(im):
    """Premultiply alpha, so rotating does not drag dark outline into the fringe."""
    px, out = im.load(), Image.new("RGBA", im.size)
    op = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a:
                op[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
    return out


def from_premul(im):
    px, out = im.load(), Image.new("RGBA", im.size)
    op = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a:
                op[x, y] = (min(255, r * 255 // a), min(255, g * 255 // a),
                            min(255, b * 255 // a), a)
    return out


def scale_alpha(im, k):
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r, g, b, a.point(lambda v: int(v * k))))


def isolate_right_wing():
    pose = Image.open(SRC).convert("RGBA").crop((0, 0, 282, 438))
    px = pose.load()
    wing = Image.new("RGBA", pose.size, (0, 0, 0, 0))
    wp = wing.load()
    for y in range(pose.size[1]):
        seam = 133 + 37.0 * (437 - y) / 287.0     # root -> the gap at y=150
        for x in range(pose.size[0]):
            if px[x, y][3] and x >= seam:
                wp[x, y] = px[x, y]
    return wing


def upright_at(wing, scale, root):
    """Wing scaled and placed with its root at `root`, axis vertical. Premultiplied.

    Only the right-hand wing is built; the left one is a mirror of the canvas
    about CX, which is why every root sits at CX + gap.
    """
    hinge = HINGE
    if scale != 1.0:
        w, h = wing.size
        wing = wing.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        hinge = (HINGE[0] * scale, HINGE[1] * scale)
    base = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    base.paste(wing, (round(root[0] - hinge[0]), round(root[1] - hinge[1])))
    return to_premul(base).rotate(-LEAN, resample=Image.BICUBIC, center=root)


def pair(upright, root, sweep, squash, alpha=1.0):
    """Symmetric pair at one stroke position, un-premultiplied."""
    im = upright
    if squash != 1.0:
        inv = 1.0 / squash
        im = im.transform(CANVAS, Image.AFFINE,
                          (1, 0, 0, 0, inv, root[1] * (1 - inv)),
                          resample=Image.BICUBIC)
    right = from_premul(im.rotate(-sweep, resample=Image.BICUBIC, center=root))
    left = right.transpose(Image.FLIP_LEFT_RIGHT)   # mirrors about CX
    out = Image.alpha_composite(left, right)
    return scale_alpha(out, alpha) if alpha != 1.0 else out


def both_pairs(fore, hind, sweep, squash, alpha=1.0):
    """Hindwings first, forewings over the top."""
    out = Image.alpha_composite(
        pair(hind, HIND_ROOT, sweep, squash),
        pair(fore, FORE_ROOT, sweep, squash))
    return scale_alpha(out, alpha) if alpha != 1.0 else out


def build_smear(fore, hind):
    ghosts = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for i in range(SMEAR_STEPS):
        t = i / (SMEAR_STEPS - 1)
        sweep = UP[0] + (DOWN[0] - UP[0]) * t
        squash = UP[1] + (DOWN[1] - UP[1]) * t
        edge = abs(t - 0.5) * 2.0       # brighter where the wings dwell
        ghosts = Image.alpha_composite(
            ghosts, both_pairs(fore, hind, sweep, squash, GHOST_ALPHA * (1 + edge)))
    ghosts = ghosts.filter(ImageFilter.GaussianBlur(GHOST_BLUR))
    mid = both_pairs(fore, hind, (UP[0] + DOWN[0]) / 2,
                     (UP[1] + DOWN[1]) / 2, SMEAR_BODY)
    return Image.alpha_composite(ghosts, mid)


FORE_ROOT = (CX + ROOT_GAP, FORE_ROOT_Y)
HIND_ROOT = (CX + ROOT_GAP * HIND_SCALE, FORE_ROOT_Y - HIND_SETBACK)


def main():
    wing = isolate_right_wing()
    fore = upright_at(wing, 1.0, FORE_ROOT)
    hind = upright_at(wing, HIND_SCALE, HIND_ROOT)

    frames = [
        both_pairs(fore, hind, *DOWN),
        build_smear(fore, hind),
        both_pairs(fore, hind, *UP),
    ]
    # head to the left, wings sweeping back to the right
    frames = [f.transpose(Image.ROTATE_90).transpose(Image.FLIP_LEFT_RIGHT)
              for f in frames]

    # one shared crop box, so the frames do not jitter against each other
    box = None
    for f in frames:
        b = f.getbbox()
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                     max(box[2], b[2]), max(box[3], b[3]))
    bw, bh = box[2] - box[0], box[3] - box[1]
    k = MAX_DIM / max(bw, bh)
    size = (max(1, round(bw * k)), max(1, round(bh * k)))

    os.makedirs(DST, exist_ok=True)
    for i, f in enumerate(frames):
        f.crop(box).resize(size, Image.LANCZOS).save(
            os.path.join(DST, f"frame_{i:03d}.png"))
    print(f"wrote 3 frames at {size[0]}x{size[1]} to {DST}")


main()
