#!/bin/sh
# Generate a tileable side-scroller background and make it a sprite in the project.
#   make_background.sh --project DIR --name spr_bg_city [--style "TEXT"] [--size 1600x900]
#                      [--label "REPLACE ME"] [--seam auto|always|never] [--quality low] [--force]
# --style is remembered in the project's style.toml and used as the default next time
# (by this and the other generating-* skills); without --style the remembered one is used.
# Seam: the wrap edge is measured after fitting; `auto` (default) runs one edit pass that
# repaints the seam when the measured step is > 3x an ordinary column step.
# Env: REPLICATE_API_TOKEN; GMX_BIN (default: gmx on PATH); BG_GEN_DIR (default ~/.cache/gmx-bg-gen/NAME).
# Work files: raw.png (the generation), fit.png (cropped), rolled.png/fixed.png (seam pass), final.png.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SIZE=1600x900; SEAM=always; QUALITY=low; FORCE=""; LABEL=""; PROP=""; PROP_HEIGHT=0.5; PROP_ASPECT=1024x1536; PROP_PASTE=""; WALK=""; PROP_METRES=""; PXPERM=120
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --name) NAME=$2; shift 2;; --style) STYLE=$2; shift 2;;
    --size) SIZE=$2; shift 2;; --label) LABEL=$2; shift 2;; --seam) SEAM=$2; shift 2;;
    --quality) QUALITY=$2; shift 2;; --force) FORCE=--force; shift;;
    --prop) PROP=$2; shift 2;; --prop-height) PROP_HEIGHT=$2; shift 2;; --prop-aspect) PROP_ASPECT=$2; shift 2;;
    --prop-paste) PROP_PASTE=1; shift;; --prop-metres) PROP_METRES=$2; shift 2;; --px-per-m) PXPERM=$2; shift 2;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${NAME:?--name}"
GMX=${GMX_BIN:-gmx}
WORK=${BG_GEN_DIR:-$HOME/.cache/gmx-bg-gen/$NAME}; mkdir -p "$WORK"
if [ -z "$STYLE" ]; then STYLE=$(python3 "$HERE/style_memory.py" get "$PROJECT") || exit 1; echo "style (from style.toml): $STYLE"; fi

SIZE_H=${SIZE#*x}
[ -n "$PROP_METRES" ] && PROP_HEIGHT=$(python3 -c "print(round($PROP_METRES * $PXPERM / $SIZE_H, 3))")
python3 "$HERE/gen_background.py" --style "$STYLE" --px-per-m "$PXPERM" --size-h "$SIZE_H" --quality "$QUALITY" --out "$WORK/raw.png"
python3 "$HERE/fit_background.py" --crop-only "$WORK/raw.png" "$WORK/cropped.png" | grep ^CROP
RATIO=$(python3 "$HERE/fit_background.py" --no-tile-crop "$WORK/cropped.png" "$WORK/fit.png" --size "$SIZE" | awk '/^SEAM/{print $2}')
echo "seam ratio $RATIO (1 = invisible, >3 = visible when the image repeats)"
SRC="$WORK/cropped.png"
NEEDS=$(python3 -c "print(1 if $RATIO > 3 else 0)")
PLACE=""
if [ -n "$PROP" ]; then
  echo "generating the prop..."
  python3 "$HERE/gen_background.py" --prop "$PROP" --style "$STYLE" --aspect "$PROP_ASPECT" --quality "$QUALITY" --out "$WORK/prop.png"
  # The repaint places the prop (and tells where the ground is); with --prop-paste it is
  # placed again exactly, on a plain repaint, at the walk line the first pass measured.
  PLACE="--place $WORK/prop.png"
fi
if [ "$SEAM" = always ] || { [ "$SEAM" = auto ] && [ "$NEEDS" = 1 ]; } || [ -n "$PLACE" ]; then
  echo "repainting the seam${PLACE:+ with the prop standing on it}..."
  python3 "$HERE/fit_background.py" --roll "$WORK/cropped.png" "$WORK/rolled.png" >/dev/null
  python3 "$HERE/gen_background.py" --fix-seam "$WORK/rolled.png" $PLACE ${PROP_METRES:+--place-metres "$PROP_METRES" --px-per-m "$PXPERM" --size-h "$SIZE_H"} --quality "$QUALITY" --out "$WORK/fixed.png" | tee "$WORK/fixed.log"
  WALK=$(awk '/^WALK/{print $2}' "$WORK/fixed.log")
  PROPH=$(awk '/^PROPHEIGHT/{print $2}' "$WORK/fixed.log")
  if [ -n "$PROP_METRES" ] && [ -n "$PROPH" ]; then
    python3 -c "
h=$PROPH; want=$PROP_HEIGHT
if abs(h-want) > 0.25*want: print(f'note: the placed prop looks {h:.0%} of the height, expected {want:.0%} for $PROP_METRES m at $PXPERM px/m; check final.png, or use --prop-paste for an exact size')"
  fi
  SRC="$WORK/fixed.png"
fi
if [ -n "$PROP_PASTE" ] && [ -n "$PROP" ]; then
  echo "repainting the seam without the prop, then pasting it at ${PROP_HEIGHT} of the height..."
  python3 "$HERE/gen_background.py" --fix-seam "$WORK/rolled.png" --quality "$QUALITY" --out "$WORK/fixedplain.png" >/dev/null
  python3 "$HERE/paste_prop.py" "$WORK/fixedplain.png" "$WORK/prop.png" "$WORK/with_prop.png" --height "$PROP_HEIGHT" ${WALK:+--ground "$WALK"} >/dev/null
  SRC="$WORK/with_prop.png"
fi
python3 "$HERE/fit_background.py" --no-tile-crop "$SRC" "$WORK/final.png" --size "$SIZE" ${WALK:+--ground "$WALK"} ${LABEL:+--label "$LABEL"} | grep -v ^WROTE

"$GMX" new sprite "$NAME" --project "$PROJECT" --source "$WORK/final.png" $FORCE
if [ -n "$WALK" ]; then
  # Readable from GML at build time as `<name>::meta.walk_frac`.
  printf '\n[meta]\nwalk_frac = %s\npx_per_m = %s\n' "$WALK" "$PXPERM" >> "$PROJECT/sprites/$NAME/sprite.toml"
else
  printf '\n[meta]\npx_per_m = %s\n' "$PXPERM" >> "$PROJECT/sprites/$NAME/sprite.toml"
fi
"$GMX" validate "$PROJECT" --no-compile -q
python3 "$HERE/style_memory.py" set "$PROJECT" "$STYLE" --by generating-backgrounds --for "$NAME" >/dev/null
if [ -n "$WALK" ]; then
  echo "BACKGROUND $PROJECT/sprites/$NAME  ($SIZE; work files in $WORK)"
  echo "WALK LINE $WALK: the prop stands just above it. Written to the sprite as [meta] walk_frac; set the world's ground_frac from it (\`$NAME::meta.walk_frac\` in GML, or $WALK on the room's obj_world instance) so characters walk in front of the prop."
else
  echo "BACKGROUND $PROJECT/sprites/$NAME  ($SIZE, ground line at 73% of the height; work files in $WORK)"
fi
echo "SCALE $PXPERM px per metre, written as [meta] px_per_m: a character_2d needs char_scale = $NAME::meta.px_per_m / 300 (1.8 m = $(python3 -c "print(round(1.8*$PXPERM))") px)."
