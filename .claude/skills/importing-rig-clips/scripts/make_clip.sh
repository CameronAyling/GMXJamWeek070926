#!/bin/sh
# Turn a Mixamo FBX animation into a gmx CLIP asset, headless, via Blender.
#   make_clip.sh --project DIR --name NAME --fbx FILE.fbx
#                [--rot-eps 0.1] [--pos-eps 1e-3] [--scale-eps 1e-4] [--force]
# Steps: FBX -> .blend (empty scene, one armature) -> posebox JSON (bones
# renumbered to the gmx template order, keyframes reduced) -> `gmx new clip`
# -> `gmx validate`.
# Env: BLENDER (default: probed, see find_blender.sh); GMX_BIN (default: gmx on PATH);
#      CLIP_GEN_DIR (default ~/.cache/gmx-clip-gen/NAME).
# Work files: NAME.blend (the import), NAME.skeleton.json (the clip before copying in).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FORCE=""; ROT=""; POS=""; SCALE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --name) NAME=$2; shift 2;; --fbx) FBX=$2; shift 2;;
    --rot-eps) ROT="--rot-eps $2"; shift 2;; --pos-eps) POS="--pos-eps $2"; shift 2;;
    --scale-eps) SCALE="--scale-eps $2"; shift 2;;
    --force) FORCE=--force; shift;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${NAME:?--name}"; : "${FBX:?--fbx}"
[ -f "$FBX" ] || { echo "no such file: $FBX" >&2; exit 2; }
B=$("$HERE/find_blender.sh") || exit 1
GMX=${GMX_BIN:-gmx}
WORK=${CLIP_GEN_DIR:-$HOME/.cache/gmx-clip-gen/$NAME}; mkdir -p "$WORK"

# 1. FBX -> .blend. Refuses anything but exactly one armature; renames the
#    action after the file (Mixamo calls every clip "mixamo.com").
"$B" -b --python "$HERE/import-fbx.py" -- "$FBX" "$WORK/$NAME.blend" 2>&1 | grep -E "^(SAVED|  |Error|expected|no such)" || true
[ -f "$WORK/$NAME.blend" ] || { echo "import failed (see above)" >&2; exit 1; }

# 2. .blend -> posebox JSON. Bone order is renumbered to the template's, so
#    the clip attaches to any gmx rig; a non-Mixamo skeleton fails here.
"$B" -b "$WORK/$NAME.blend" --python "$HERE/export-clip.py" -- "$WORK/$NAME.skeleton.json" $ROT $POS $SCALE 2>&1 \
  | grep -E "^(WROTE|  |BONES|  absent|  extra|cannot|reference)" || true
[ -f "$WORK/$NAME.skeleton.json" ] || { echo "export failed (see above)" >&2; exit 1; }

# 3. Into the project.
"$GMX" new clip "$NAME" --project "$PROJECT" --from "$WORK/$NAME.skeleton.json" $FORCE
"$GMX" validate "$PROJECT" --no-compile -q
echo "CLIP $PROJECT/clips/$NAME  (from $(basename "$FBX"); work files in $WORK)"
