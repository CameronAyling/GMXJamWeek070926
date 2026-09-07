# Import a Mixamo FBX into an EMPTY scene and save it as a .blend.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/import-fbx.py \
#     -- "/path/to/Strut Walking.fbx" tools/blender/strut-walking.blend
#
# Starts from an EMPTY scene: `-b` alone does not — the startup file ships a
# cube, a camera and a light.
# Mixamo names every clip "mixamo.com"; the action is renamed after the FBX
# (the posebox exporter takes the clip name from the action).
# Checking the rig against the project's reference is export-clip.py's job.

import os
import sys

import bpy


def clear_scene():
    """An empty scene: no cube, no camera, no light, no leftover data."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(fbx_path):
    if not os.path.exists(fbx_path):
        raise SystemExit(f"no such file: {fbx_path}")
    bpy.ops.import_scene.fbx(
        filepath=fbx_path,
        # Keeps bone ROLL consistent with the reference import; roll changes
        # the parent-local transforms the clip exports.
        automatic_bone_orientation=True,
    )


def main(fbx_path, blend_path):
    clear_scene()
    import_fbx(fbx_path)

    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        raise SystemExit(
            f"expected exactly one armature, found {len(armatures)}: "
            f"{[o.name for o in armatures]}"
        )
    rig = armatures[0]

    # Name the action after the file, so the exported clip says what it is.
    stem = os.path.splitext(os.path.basename(fbx_path))[0]
    if rig.animation_data and rig.animation_data.action:
        rig.animation_data.action.name = stem

    os.makedirs(os.path.dirname(os.path.abspath(blend_path)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(blend_path))

    action = rig.animation_data.action if rig.animation_data else None
    print(f"SAVED {blend_path}")
    print(f"  objects  : {[o.name + ':' + o.type for o in bpy.data.objects]}")
    print(f"  armature : {rig.name}, {len(rig.data.bones)} bones")
    if action:
        start, end = action.frame_range
        print(f"  action   : {action.name!r} frames {start:.0f}-{end:.0f}")
    else:
        print("  action   : NONE — this FBX carries no animation")


if __name__ == "__main__":
    if "--" not in sys.argv:
        raise SystemExit(
            "usage: blender -b --python this.py -- <in.fbx> <out.blend>"
        )
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 2:
        raise SystemExit("expected exactly: <in.fbx> <out.blend>")
    main(args[0], args[1])
