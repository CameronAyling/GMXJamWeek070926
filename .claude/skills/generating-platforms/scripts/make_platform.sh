#!/bin/sh
# Generate a horizontally stretchable platform sprite (three-slice: two caps and a
# repeating centre) and write it into the project:
#   make_platform.sh --project . --name spr_platform_steel --style "a riveted steel walkway, neon city night"
# Options: --reference IMG (match this scene's style; defaults to no reference), --height PX
# (the sprite's height, default 64), --quality low|medium|high (default low), --force (replace an
# existing sprite of that name), --raw IN.png (slice this painting instead of generating one).
# Without --style the project's style.toml is used.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
HEIGHT=64; QUALITY=low; FORCE=""; REF=""; STYLE=""; RAW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --name) NAME=$2; shift 2;; --style) STYLE=$2; shift 2;;
    --reference) REF=$2; shift 2;; --height) HEIGHT=$2; shift 2;; --quality) QUALITY=$2; shift 2;;
    --force) FORCE=--force; shift;;  --raw) RAW=$2; shift 2;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${NAME:?--name}"
GMX=${GMX_BIN:-gmx}
[ -n "$STYLE" ] || STYLE=$(python3 "$HERE/style_memory.py" get "$PROJECT")
WORK=${PLATFORM_GEN_DIR:-$HOME/.cache/gmx-platform-gen}/$NAME; mkdir -p "$WORK"

if [ -n "$RAW" ]; then [ "$RAW" -ef "$WORK/raw.png" ] || cp "$RAW" "$WORK/raw.png"; else
  python3 "$HERE/gen_platform.py" --style "$STYLE" ${REF:+--reference "$REF"} --quality "$QUALITY" --out "$WORK/raw.png"
fi
python3 "$HERE/slice_platform.py" "$WORK/raw.png" "$WORK/platform.png" --height "$HEIGHT" --preview "$WORK/preview.png" > "$WORK/slice.txt"
cat "$WORK/slice.txt"
LEFT=$(sed -n 's/^LEFT \([0-9]*\) RIGHT \([0-9]*\)/\1/p' "$WORK/slice.txt")
RIGHT=$(sed -n 's/^LEFT \([0-9]*\) RIGHT \([0-9]*\)/\2/p' "$WORK/slice.txt")
SEAM=$(sed -n 's/^SEAM //p' "$WORK/slice.txt")

"$GMX" new sprite "$NAME" --project "$PROJECT" --source "$WORK/platform.png" $FORCE
TOML="$PROJECT/sprites/$NAME/sprite.toml"
grep -q "^\[nine_slice\]" "$TOML" 2>/dev/null && { echo "$TOML already has [nine_slice]" >&2; exit 1; }
cat >> "$TOML" <<TOML

# Three-slice: the caps keep their width, the centre repeats. Stretch it with
# draw_sprite_stretched or image_xscale; the height stays as painted.
[nine_slice]
enabled = true
left = $LEFT
right = $RIGHT
top = 0
bottom = 0
tile_mode = ["stretch", "stretch", "stretch", "stretch", "repeat"]
TOML
python3 "$HERE/style_memory.py" set "$PROJECT" "$STYLE" --by generating-platforms --for "$NAME" >/dev/null 2>&1 || true
"$GMX" validate "$PROJECT" --no-compile -q
echo "PLATFORM $NAME: caps $LEFT/$RIGHT px, seam $SEAM; look at $WORK/preview.png (three widths)"
echo "USE: an obj_wall instance with platform_sprite = $NAME and scale_y = $HEIGHT; scale_x is its width"
