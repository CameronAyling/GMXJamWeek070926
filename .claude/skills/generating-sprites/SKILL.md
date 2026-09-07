---
name: generating-sprites
description: Use when asked to create, generate or add a single game-object sprite / prop / item / projectile image to this gmx project ("generate a shuriken", "make a coin sprite") — AI-generated on a transparent background, in the project's existing style unless told otherwise
---

# Generating sprites

## Overview

One command turns "a four-pointed steel shuriken" into a sprite: `openai/gpt-image-2`
on Replicate paints one object on a transparent background in the project's
style, the result is cleaned to hard alpha, cropped to its bounds, scaled to a
height, and `gmx new sprite` writes it in with a centred origin. The style comes
from `style.toml` — whatever the last character or background was generated
in — so a prop made after a ninja-turtle character looks like it belongs to it.

## When to use

- "generate an X", "add a sprite for Y", "I need a coin / key / rock / shuriken"
- NOT for characters that animate (generating-rig-characters) or backgrounds
  (generating-backgrounds); NOT for sprite sheets — one object, one frame

## Run it

```sh
export REPLICATE_API_TOKEN=…     # Replicate billing
# needs: gmx on PATH (or GMX_BIN), python3 with Pillow

S=.claude/skills/generating-sprites/scripts
$S/make_sprite.sh --project . --name spr_shuriken --subject "a four-pointed steel shuriken"
# explicit style, and a prop that stands on the ground:
$S/make_sprite.sh --project . --name spr_crate --subject "a wooden crate" \
  --style "flat cel-shaded, 90s cartoon" --origin bottom --height 160
```

Result: `sprites/<name>/frame_000.png` + `sprite.toml` (origin set), project
validated, `style.toml` updated. Work files in `~/.cache/gmx-sprite-gen/<name>/`:
`raw.png` (the generation, 1024²), `final.png`. One Replicate call, ~15–30 s.

`--subject` is the thing; `--style` the look. With no `--style` the project's
`style.toml` supplies the last one used by any generating-* skill; with no
`style.toml` either, the script stops and asks for one — pick a style that
matches what is already in the project rather than inventing a new one.
`--inspiration IMG` adds a reference image to copy the look from.

## Options

| Flag | Default | Notes |
|---|---|---|
| `--height N` | `128` | output height in px, width follows; `0` keeps the generated size |
| `--origin` | `centre` | `centre` for things that fly or spin, `bottom` for things standing on the ground |
| `--quality` | `low` | `low` is fine for a 128 px sprite |

## Reading the result

- **`PARTS n`** printed after cleaning: `1` is right. `2+` means the model
  drew extra pieces (a shadow blob, a second copy, a ground line) — regenerate,
  or add "single object, nothing else" detail to `--subject`.
- **`PARTS 0` / "fully transparent"**: the backdrop came back opaque and the
  alpha threshold removed everything, or vice versa. Regenerate.
- **Wrong angle**: the prompt asks for a side view at eye level (to match the
  side-view characters); a top-down prop needs "seen from above" in `--subject`.
- Using it as a physics object: give the object a circle or polygon shape in
  `object.toml` sized to the sprite (a 128 px shuriken ≈ radius 56 centred
  at [64, 64]) — see the character_2d README for the hit → ragdoll hand-off.

## Common mistakes

- Asking for several objects in one call ("a sword and a shield") — one
  subject per sprite; call it twice.
- Editing the generated PNG by hand to fix alpha — regenerate or adjust
  `--threshold` in `fit_sprite.py` instead.
- Forgetting `--force` when replacing an existing sprite name.
