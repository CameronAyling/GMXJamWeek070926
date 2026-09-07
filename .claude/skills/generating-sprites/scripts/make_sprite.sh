#!/bin/sh
# Generate a single-object sprite and add it to the project, in the project's style.
#   make_sprite.sh --project DIR --name spr_shuriken --subject "a four-pointed steel shuriken"
#                  [--style "TEXT"] [--inspiration IMG] [--height 128] [--origin centre|bottom|top_left]
#                  [--quality low] [--force]
# Without --style the project's style.toml (written by every generating-* skill) supplies the
# look, so a prop made after a character or a background matches them.
# Env: REPLICATE_API_TOKEN; GMX_BIN (default: gmx on PATH); SPRITE_GEN_DIR (default ~/.cache/gmx-sprite-gen/NAME).
# Work files: raw.png (the generation), final.png (cropped, hard alpha, scaled).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
HEIGHT=128; QUALITY=low; FORCE=""; ORIGIN=centre
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --name) NAME=$2; shift 2;; --subject) SUBJECT=$2; shift 2;;
    --style) STYLE=$2; shift 2;; --inspiration) INSP=$2; shift 2;; --height) HEIGHT=$2; shift 2;;
    --origin) ORIGIN=$2; shift 2;;
    --quality) QUALITY=$2; shift 2;; --force) FORCE=--force; shift;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${NAME:?--name}"; : "${SUBJECT:?--subject}"
GMX=${GMX_BIN:-gmx}
WORK=${SPRITE_GEN_DIR:-$HOME/.cache/gmx-sprite-gen/$NAME}; mkdir -p "$WORK"
if [ -z "$STYLE" ]; then STYLE=$(python3 "$HERE/style_memory.py" get "$PROJECT") || exit 1; echo "style (from style.toml): $STYLE"; fi

python3 "$HERE/gen_sprite.py" --subject "$SUBJECT" --style "$STYLE" ${INSP:+--inspiration "$INSP"} --quality "$QUALITY" --out "$WORK/raw.png"
python3 "$HERE/fit_sprite.py" "$WORK/raw.png" "$WORK/final.png" --height "$HEIGHT" | grep -v ^WROTE
"$GMX" new sprite "$NAME" --project "$PROJECT" --source "$WORK/final.png" $FORCE
# The origin: centre for things that spin and fly (the default), bottom for
# things that stand on the ground. gmx new sprite scaffolds top_left.
printf '\n# Set by generating-sprites: %s so it rotates/sits about the right point.\norigin = "%s"\n' "$ORIGIN" "$ORIGIN" >> "$PROJECT/sprites/$NAME/sprite.toml"
"$GMX" validate "$PROJECT" --no-compile -q
python3 "$HERE/style_memory.py" set "$PROJECT" "$STYLE" --by generating-sprites --for "$NAME" >/dev/null
echo "SPRITE $PROJECT/sprites/$NAME  (work files in $WORK)"
