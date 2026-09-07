#!/bin/sh
# Generate a paper-doll character sheet and create a gmx rig from it.
#   make_rig.sh --project DIR --name NAME [--view side|iso_se|iso_ne]
#               (--style "TEXT" [--inspiration IMG] | --spec FILE | --sheet READY.png)
#               [--order 4,3,2,1,0] [--quality low] [--force]
# iso_se also writes spec.txt (the character specification) next to the sheet; make the matching
# iso_ne rig with `--view iso_ne --spec <that file>`.
# Env: REPLICATE_API_TOKEN; GMX_BIN (default: gmx on PATH); RIG_GEN_DIR (default ~/.cache/gmx-rig-gen/NAME).
# Work files: raw.png (the generation), sheet.png (the atlas), spec.txt (iso_se), overlay.png (chains over the atlas).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
VIEW=side; QUALITY=low; FORCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --name) NAME=$2; shift 2;; --style) STYLE=$2; shift 2;;
    --spec) SPEC=$2; shift 2;; --inspiration) INSP=$2; shift 2;; --sheet) SHEET=$2; shift 2;;
    --view) VIEW=$2; shift 2;; --order) ORDER=$2; shift 2;; --quality) QUALITY=$2; shift 2;;
    --force) FORCE=--force; shift;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${NAME:?--name}"
GMX=${GMX_BIN:-gmx}
WORK=${RIG_GEN_DIR:-$HOME/.cache/gmx-rig-gen/$NAME}; mkdir -p "$WORK"

if [ -z "$SHEET" ]; then
  case "$VIEW" in
    iso_ne) : "${SPEC:?iso_ne needs --spec FILE (from the iso_se run)}"
            python3 "$HERE/gen_atlas.py" --view iso_ne --spec "$SPEC" --quality "$QUALITY" --out "$WORK/raw.png";;
    side|iso_se) : "${STYLE:?$VIEW needs --style TEXT}"
            python3 "$HERE/gen_atlas.py" --view "$VIEW" --style "$STYLE" ${INSP:+--inspiration "$INSP"} --quality "$QUALITY" --out "$WORK/raw.png";;
    *) echo "unsupported view $VIEW (side, iso_se, iso_ne)"; exit 2;;
  esac
  SHEET="$WORK/raw.png"
fi
python3 "$HERE/fix_sheet.py" "$SHEET" "$WORK/sheet.png" ${ORDER:+--order "$ORDER"}
"$GMX" new rig "$NAME" --project "$PROJECT" --atlas "$WORK/sheet.png" --view "$VIEW" $FORCE
"$GMX" validate "$PROJECT"
python3 "$HERE/overlay.py" "$WORK/sheet.png" "$PROJECT/rigs/$NAME/rig.json" "$WORK/overlay.png"
if [ "$VIEW" = iso_se ] && [ -z "$SPEC" ]; then
  python3 "$HERE/spec.py" "$WORK/sheet.png" "$WORK/spec.txt"
fi
echo "RIG $PROJECT/rigs/$NAME  ($(grep ^atlas "$PROJECT/rigs/$NAME/rig.toml"))  overlay: $WORK/overlay.png"
