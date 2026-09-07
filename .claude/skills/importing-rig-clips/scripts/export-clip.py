# Export a skeleton + animation from a .blend using posebox's own exporter.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b work/jump.blend \
#     --python scripts/export-clip.py -- work/jump.skeleton.json [--reference template.skeleton.json]
#
# Skill copy of gmx's tools/blender/export-clip.py: the bone-order reference
# is the vendored assets/template.skeleton.json beside this skill (or
# --reference), since a consumer project has no gmx checkout to read it from.
#
# posebox's exporter is a Blender ADD-ON: headless it must be loaded and
# registered by hand, and told to skip meshes/materials/lights/cameras.
# Bones are then reordered to match the reference sample — tracks reference
# bones by INDEX (rig-core's skeletonsCompatible enforces this).

import argparse
import importlib.util
import json
import math
import os
import sys

import bpy

# posebox's exporter add-on, vendored beside this script (upstream: the posebox repo).
POSEBOX_EXPORTER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "posebox_exporter.py")

# Bone order to match, so clips built here attach to every gmx rig (the
# template skeleton every atlas is fitted against). Overridable with --reference.
REFERENCE_SAMPLE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "template.skeleton.json"
)

# Keyframe reduction: a key survives only if dropping it would move another
# key off its interpolated value by more than its channel's tolerance.
# Rotation tolerance is the true quaternion angle in degrees (error compounds
# down a chain); position is in armature units (~1 cm); scale is constant 1
# in Mixamo clips but tolerated so a scale-animating rig isn't flattened.
# Defaults chosen from measured end-effector drift on the hip-hop clip:
# 0.1 deg => 2.42 mm worst bone-tail drift (~0.7 px at the preview's
# 300 px/m), the last setting comfortably sub-pixel. Raise --rot-eps if size
# matters more than exactness.
DEFAULT_POS_EPS = 1e-3
DEFAULT_ROT_EPS_DEG = 0.1
DEFAULT_SCALE_EPS = 1e-4


def load_exporter():
    """Import posebox's add-on and register its operator, without installing it."""
    spec = importlib.util.spec_from_file_location(
        "posebox_exporter", POSEBOX_EXPORTER
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules["posebox_exporter"] = module
    spec.loader.exec_module(module)
    module.register()
    return module


def reorder_to_reference(doc, ref_path):
    """Renumber bones (and the tracks indexing them) into the reference order."""
    if not os.path.exists(ref_path):
        # Authored order silently produces a clip that will not attach, so
        # this is an error here rather than the NOTE the repo script prints.
        raise SystemExit(f"reference skeleton missing: {ref_path} — pass --reference")
    with open(ref_path) as f:
        want = [b["name"] for b in json.load(f)["skeleton"]["bones"]]
    bones = doc["skeleton"]["bones"]
    have = {b["name"]: i for i, b in enumerate(bones)}
    missing = set(want) - set(have)
    extra = set(have) - set(want)
    if missing or extra:
        print(f"BONES DIFFER from {ref_path}:")
        if missing:
            print(f"  absent here : {sorted(missing)}")
        if extra:
            print(f"  extra here  : {sorted(extra)}")
        raise SystemExit("cannot reorder safely — clip will not attach. Only Mixamo rigs "
                         "(65 `mixamorig:` bones) are supported; re-download the clip on a "
                         "Mixamo character, or retarget it in Blender first")

    old_to_new = {have[n]: i for i, n in enumerate(want)}
    reordered = []
    for name in want:
        b = dict(bones[have[name]])
        b["parent"] = old_to_new[b["parent"]] if b["parent"] >= 0 else -1
        reordered.append(b)
    # FK walks the list once, so a parent must precede its children.
    assert all(b["parent"] < i for i, b in enumerate(reordered)), "parent ordering"

    for anim in doc["animations"]:
        for track in anim["tracks"]:
            track["bone"] = old_to_new[track["bone"]]
        anim["tracks"].sort(key=lambda t: t["bone"])
    doc["skeleton"]["bones"] = reordered


def normalized(q):
    """Unit quaternion. The exporter rounds rotations to 4 decimals, so keys
    read back are NOT unit (|q| ~ 0.99994); unnormalized, a rotation compared
    to ITSELF reads ~1.7 deg apart. Used for the reduction pass's own
    comparisons only — written keys keep posebox's 4 decimals, and every
    clip reader normalizes rotations at load."""
    n = math.sqrt(sum(x * x for x in q)) or 1.0
    return [x / n for x in q]


def slerp(q0, q1, t):
    """Shortest-arc quaternion interpolation, matching what a player does."""
    q0 = normalized(q0)
    q1 = normalized(q1)
    dot = sum(q0[i] * q1[i] for i in range(4))
    if dot < 0:
        q1 = [-x for x in q1]
        dot = -dot
    if dot > 0.9995:
        out = [q0[i] + t * (q1[i] - q0[i]) for i in range(4)]
    else:
        th = math.acos(max(-1.0, min(1.0, dot)))
        s = math.sin(th)
        out = [
            (math.sin((1 - t) * th) * q0[i] + math.sin(t * th) * q1[i]) / s
            for i in range(4)
        ]
    n = math.sqrt(sum(x * x for x in out)) or 1.0
    return [x / n for x in out]


def quat_angle_deg(a, b):
    """Angle between two orientations, sign-insensitive (q and -q are equal)."""
    a = normalized(a)
    b = normalized(b)
    dot = abs(sum(a[i] * b[i] for i in range(4)))
    return 2 * math.degrees(math.acos(max(-1.0, min(1.0, dot))))


def reduce_keyframes(keys, pos_eps, rot_eps, scale_eps):
    """Drop keys a straight interpolation would have reproduced anyway.

    Greedy fit-and-drop, not neighbour-similarity (which would flatten a slow
    ramp): every dropped key must land within tolerance of the line (or arc)
    between the keys that SURVIVE.
    """
    if len(keys) < 3:
        return list(keys)

    def within(lo, hi, mid):
        span = hi["time"] - lo["time"]
        t = 0.0 if span <= 0 else (mid["time"] - lo["time"]) / span
        for channel, eps in (("pos", pos_eps), ("scale", scale_eps)):
            a, b, m = (x["transform"][channel] for x in (lo, hi, mid))
            for i in range(3):
                if abs(a[i] + t * (b[i] - a[i]) - m[i]) > eps:
                    return False
        got = slerp(lo["transform"]["rot"], hi["transform"]["rot"], t)
        return quat_angle_deg(got, mid["transform"]["rot"]) <= rot_eps

    out = [keys[0]]
    anchor = 0
    i = 1
    while i < len(keys) - 1:
        if all(within(keys[anchor], keys[i + 1], keys[j]) for j in range(anchor + 1, i + 1)):
            i += 1
        else:
            out.append(keys[i])
            anchor = i
            i += 1
    out.append(keys[-1])
    return out


def main(out_path, reference, pos_eps, rot_eps, scale_eps):
    load_exporter()

    bpy.ops.export_scene.posebox(
        filepath=out_path,
        file_format="JSON",
        export_skeleton=True,
        export_animations=True,
        # A skinmesh character's art is its atlas; none of this travels.
        export_meshes=False,
        export_materials=False,
        export_lights=False,
        export_cameras=False,
        export_textures=False,
        animation_sample_rate=30,
        # Every bone, even still ones: a missing track leaves the bone at rest.
        optimize_static_bones=False,
    )

    with open(out_path) as f:
        doc = json.load(f)
    reorder_to_reference(doc, reference)
    # posebox's "physics"/"attachments" are scene props, not a skinmesh
    # character's attachments; dropped so committed clips share one shape.
    for empty in ("physics", "attachments"):
        doc.pop(empty, None)

    before = sum(len(t["keyframes"]) for a in doc["animations"] for t in a["tracks"])
    for anim in doc["animations"]:
        for track in anim["tracks"]:
            track["keyframes"] = reduce_keyframes(
                track["keyframes"], pos_eps, rot_eps, scale_eps
            )
    after = sum(len(t["keyframes"]) for a in doc["animations"] for t in a["tracks"])

    with open(out_path, "w") as f:
        json.dump(doc, f, separators=(",", ":"))

    anims = doc.get("animations", [])
    print(f"WROTE {out_path}")
    print(f"  bones      : {len(doc['skeleton']['bones'])}")
    for a in anims:
        print(
            f"  animation  : {a['name']!r} {a['duration']:.2f}s "
            f"@{a['sample_rate']}fps, {len(a['tracks'])} tracks"
        )
    print(
        f"  keyframes  : {before} -> {after} "
        f"({100.0 * after / before:.1f}%) at pos {pos_eps:g}, "
        f"rot {rot_eps:g} deg, scale {scale_eps:g}"
    )


if __name__ == "__main__":
    if "--" not in sys.argv:
        raise SystemExit(
            "usage: blender -b <file> --python this.py -- <out.json> [options]"
        )
    ap = argparse.ArgumentParser(prog="export-clip.py")
    ap.add_argument("out_path")
    ap.add_argument("--reference", default=REFERENCE_SAMPLE,
                    help="skeleton JSON whose bone order the clip is renumbered to")
    ap.add_argument("--pos-eps", type=float, default=DEFAULT_POS_EPS)
    ap.add_argument("--rot-eps", type=float, default=DEFAULT_ROT_EPS_DEG,
                    help="degrees of true quaternion angle")
    ap.add_argument("--scale-eps", type=float, default=DEFAULT_SCALE_EPS)
    ns = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
    main(ns.out_path, ns.reference, ns.pos_eps, ns.rot_eps, ns.scale_eps)
