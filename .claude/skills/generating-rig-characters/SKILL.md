---
name: generating-rig-characters
description: Use when asked to create, generate or add a new paper-doll rig character to this gmx project from a style description or an inspiration image (AI-generated character sheet → rig), for the side view or the isometric SE/NE views
---

# Generating rig characters

## Overview

One command turns "a pirate in a Sims look" (or a reference picture) into a
buildable rig: the view's layout template goes to `openai/gpt-image-2`
(`quality=low`, ~35 s) on Replicate with a prompt that pins the 5-part layout
and the loose-fist hands, the result is cleaned into an atlas, and
`gmx new rig --atlas --view` fits the chains and writes every project entry.
Nothing is written by hand.

## When to use

- "make me a character / rig for X", "add a rig that looks like this image"
- an isometric character: the SE (front-right) sheet, then the NE (back-right)
  sheet of the same character
- NOT for re-fitting an existing rig (open it in the rig editor)

## Run it

```sh
export REPLICATE_API_TOKEN=…     # Replicate billing; <$5 credit throttles to 1 request at a time
# needs: gmx on PATH (or GMX_BIN), python3 with Pillow, nothing else

S=.claude/skills/generating-rig-characters/scripts
$S/make_rig.sh --project . --name rig_pirate \
  --style "a cartoon pirate captain, Sims 4 look, red coat, wooden leg" [--inspiration ref.png]

# isometric pair: SE first (also writes the character spec), then NE from that spec
$S/make_rig.sh --project . --name rig_pirate_se --view iso_se --style "…"
$S/make_rig.sh --project . --name rig_pirate_ne --view iso_ne --spec ~/.cache/gmx-rig-gen/rig_pirate_se/spec.txt
```

Result: `rigs/<name>/rig.toml` + `rig.json`, `sprites/spr_<name>_atlas/`
(`for_3d = true`), project validated. Work files in
`~/.cache/gmx-rig-gen/<name>/`: `raw.png` (the generation), `sheet.png` (the
atlas), `spec.txt` (iso_se), **`overlay.png`** — always open the overlay and
check that each chain sits on its own part before calling it done, then ask
the user to look at it too.

`--style` is the character: materials, colours and look, not pose (the prompt
owns the pose). `--inspiration` adds the image as a second input the prompt
tells the model to copy the look from, layout untouched. The NE sheet never
takes a style: `spec.py` describes the SE character (a vision model on
Replicate, `openai/gpt-5`) and the NE prompt carries that specification, so
the two sheets are the same character from behind.

## Attachments

Hats, gloves, shields, packs: things a game toggles or swaps at runtime
(`rig_set_attachment_visible`, `rig_set_attachment_sprite`) rather than
baking into the atlas.

```sh
$S/make_attachment.sh --project . --rig rig_pirate --name hat --item "a red tricorn hat" --bone head
$S/make_attachment.sh --project . --rig rig_pirate --name gloves --item "a black leather glove" --bone hands
```

The item is painted alone on a transparent background with the rig's atlas
as the style and camera reference, becomes `sprites/spr_<rig>_<name>`, and
`attach.py` appends the `[[attachment]]` to `rig.toml`: at the bone's end
in atlas space, sized by the bone it rides (a hat 1.4× the head bone,
a hand item 1.3× the hand bone; `--size F` overrides as a fraction of the
character's height), upright at bind pose (`--angle` to tilt), just in front
of its own chain in `draw_order` (`--behind CHAIN` to tuck it behind one).
`--bone hands` makes a **pair**: the far hand's item is painted from its
palm side, the near hand's from the back of the hand, attached as
`<name>_l` / `<name>_r` — a mirrored character shows the right side of each.
Check the work dir's `preview.png` (atlas + item at bind), then a game
screenshot: the preview cannot show the runtime pose. Too big or small:
rerun `attach.py` alone with `--size` (no new generation needed).

## Stages (for running one by hand)

| Stage | Script | Notes |
|---|---|---|
| generate | `gen_atlas.py --view V --style … --out raw.png` (`--spec FILE` for iso_ne) | template + prompt per view in `assets/`; writes `raw.png.prompt.txt` |
| describe | `spec.py sheet.png spec.txt` | the iso_se → iso_ne hand-off |
| clean + pack | `fix_sheet.py raw.png sheet.png [--order 4,3,2,1,0]` | hard alpha, exactly 5 parts (else it exits loudly), packed by x with a 28 px gutter; writes `sheet.parts.json` |
| create | `gmx new rig NAME --atlas sheet.png --view V` | fits the chains (prints which fit won), writes rig.json, rig.toml, sprite; then `gmx validate` |
| check | `overlay.py sheet.png rigs/NAME/rig.json overlay.png` | bones + mesh wireframe over the atlas |

## Reading the result

- **Parts ≠ 5**: the model fused or split a part (pelvis touching a leg, a hat
  floating free). Regenerate; a second run is cheap. Do not hand-edit unless
  the user asks.
- **Limbs swapped** (near arm drawn on the left): `fix_sheet.py --order
  4,3,2,1,0` mirrors the part order. Judge from the art: the LEFT (far) arm
  shows the palm side of the fist, the RIGHT (near) arm the back of it.
- **"uniform fit only"** from `gmx new rig`: the sheet didn't read as a packed
  layout; the overlay will show limbs off their parts. Regenerate rather than
  ship it.
- **Iso torso facing the wrong way** (left shoulder nearest, centre line on
  the wrong half): the prompt's orientation paragraph lost; regenerate.
- Open hands / splayed fingers: regenerate (adding the style's glove or
  sleeve detail sometimes helps).
- **Neck hidden** (high collar, scarf, mane): the prompt asks for an
  exposed neck so the head skins onto the torso cleanly; if the style
  demands a collar, expect to adjust the neck vertices in the rig editor.
- Opaque backdrop in `raw.png`: gpt-image-2 does not always honour
  "transparent"; `fix_sheet.py` thresholds alpha, so it only matters when a
  part came back fused to the backdrop (then it reports ≠ 5 parts).

## Common mistakes

- Writing `rig.toml`/`sprite.toml`/`rig.json` by hand — `gmx new rig` owns
  them (the sprite must be `for_3d = true`, the fit must match the view).
- Using another template or an old open-hand one: the prompts describe
  exactly the images in `assets/` (loose fists, labelled iso views).
- `quality=high`: ~3× slower for no better layout adherence. Replicate ignores
  `size` for gpt-image-2; nano-banana / seedream / flux-kontext ignore the
  hand and separate-part rules.
- Giving the NE run a `--style`: it drifts into a different character. Always
  go through the spec.
