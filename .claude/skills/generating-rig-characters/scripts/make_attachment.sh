#!/bin/sh
# Generate an accessory in a rig's own style and attach it to a bone:
#   make_attachment.sh --project . --rig rig_pirate --name hat --item "a red tricorn hat" --bone head
# Options: --size F (height as a fraction of the character's height; default: sized by the bone it
# rides), --anchor end|start|mid, --offset DX,DY, --angle DEG, --behind CHAIN, --quality low|medium|high
# (default low). The item is painted on a transparent background with the rig's atlas as the style
# reference, becomes sprites/spr_<rig>_<name>, and attach.py places it.
# --bone hands makes a PAIR: the far (left) hand's item shows its palm side, the near (right) hand's
# its back, attached as <name>_l and <name>_r -- what a mirrored character needs.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SIZE=""; ANCHOR=end; OFFSET=0,0; ANGLE=0; BEHIND=""; QUALITY=low
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=$2; shift 2;; --rig) RIG=$2; shift 2;; --name) NAME=$2; shift 2;;
    --item) ITEM=$2; shift 2;; --bone) BONE=$2; shift 2;; --size) SIZE=$2; shift 2;;
    --anchor) ANCHOR=$2; shift 2;; --offset) OFFSET=$2; shift 2;; --angle) ANGLE=$2; shift 2;;
    --behind) BEHIND=$2; shift 2;; --quality) QUALITY=$2; shift 2;;
    *) echo "unknown arg $1"; exit 2;;
  esac
done
: "${PROJECT:?--project}"; : "${RIG:?--rig}"; : "${NAME:?--name}"; : "${ITEM:?--item}"; : "${BONE:?--bone}"
GMX=${GMX_BIN:-gmx}
WORK=${RIG_GEN_DIR:-$HOME/.cache/gmx-rig-gen/$RIG}/attachments/$NAME; mkdir -p "$WORK"
ATLAS=$(sed -n 's/^atlas = "\(.*\)"/\1/p' "$PROJECT/rigs/$RIG/rig.toml")
[ -n "$ATLAS" ] || { echo "no atlas in $PROJECT/rigs/$RIG/rig.toml" >&2; exit 1; }

one() { # suffix side bone
  W=$WORK$1; mkdir -p "$W"
  python3 "$HERE/gen_atlas.py" --item "$ITEM" --reference "$PROJECT/sprites/$ATLAS/frame_000.png" ${2:+--side "$2"} \
    --quality "$QUALITY" --out "$W/raw.png"
  python3 "$HERE/trim_alpha.py" "$W/raw.png" "$W/item.png"
  SPRITE=spr_${RIG#rig_}_$NAME$1
  "$GMX" new sprite "$SPRITE" --project "$PROJECT" --source "$W/item.png" --force
  python3 "$HERE/attach.py" --project "$PROJECT" --rig "$RIG" --name "$NAME$1" --sprite "$SPRITE" --bone "$3" \
    --anchor "$ANCHOR" ${SIZE:+--size "$SIZE"} --offset "$OFFSET" --angle "$ANGLE" ${BEHIND:+--behind "$BEHIND"} --preview "$W/preview.png"
}
if [ "$BONE" = hands ]; then
  one _l far left_hand
  one _r near right_hand
else
  one "" "" "$BONE"
fi
"$GMX" validate "$PROJECT" --no-compile -q
echo "ATTACHMENT $NAME on $RIG; look at $WORK*/preview.png, then a screenshot of the game -- the atlas preview cannot show the runtime pose"
