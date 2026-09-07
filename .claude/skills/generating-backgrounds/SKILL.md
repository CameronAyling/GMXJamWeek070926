---
name: generating-backgrounds
description: Use when asked to create, generate, change or replace a side-scroller background / backdrop / scenery image for this gmx project from a style description ("a ninja-turtle style city street", "a misty forest") — AI-generated, horizontally tileable, fitted to 1600×900 with a known ground line
---

# Generating backgrounds

## Overview

One command turns "a rainy neon Tokyo alley" into a background sprite the
side-scroller world can scroll: `openai/gpt-image-2` on Replicate paints a
16:9 image over the skill's ground-line template (so the ground sits at a
known height and is seen slightly from above — shadows land on it), the
prompt asks for a horizontal tile with a plain full-height surface at
both edges, the crop is placed where the two edges match best, the wrap
seam is rolled to the middle and repainted by a second edit pass on just
that strip, an optional prop generated on a transparent background is
stood over it, and `gmx new sprite` writes it in. The style is remembered in
the project's `style.toml` for the other generating-* skills.

## When to use

- "change the background to X", "make the backdrop a Y", "new level art"
- NOT for characters (generating-rig-characters) or single props
  (generating-sprites)

## Run it

```sh
export REPLICATE_API_TOKEN=…     # Replicate billing; <$5 credit throttles to 1 request at a time
# needs: gmx on PATH (or GMX_BIN), python3 with Pillow

S=.claude/skills/generating-backgrounds/scripts
$S/make_background.sh --project . --name spr_bg_city \
  --style "a city street in the style of a 90s ninja turtles cartoon, night, neon signs"

# replace the world prefab's placeholder in place (same sprite name, so nothing else changes):
$S/make_background.sh --project . --name spr_bg --style "…" --force
```

Result: `sprites/<name>/frame_000.png` (1600×900), project validated,
`style.toml` updated, and with `--prop` a `WALK LINE <fraction>`: where the
prop meets the ground, plus a little. It is also written into the sprite's
`sprite.toml` as `[meta] walk_frac`, readable at build time as
`<name>::meta.walk_frac`. Feed it to the world's `ground_frac` (the
prefab's `ground_y` derives from it) — `ground_frac = spr_bg::meta.walk_frac;`
in `obj_world`'s Create, or the value on the room's `obj_world` instance —
so characters walk in front of the prop rather than behind or through it.

**Scale.** The scene is generated to a scale: `--px-per-m` (default 120,
so a 1.8 m person is 24% of a 900-high backdrop) tells the model how big
doors, storeys and vehicles are, sizes the prop when its real height is
given (`--prop-metres 2.4` for a van, 2.1 for a door-height thing), and is
written as `[meta] px_per_m`. A `character_2d` rig is 300 px per metre at
`char_scale = 1`, so `char_scale = spr_bg::meta.px_per_m / 300` sizes it to
the scene. Cartoon metres are loose (±20%); the driver notes when the
placed prop came out far from its expected size. Work files in `~/.cache/gmx-bg-gen/<name>/`: `raw.png`
(the generation), `cropped.png`, `rolled.png`/`fixed.png` (the seam pass;
`fixed.png.strip.png` and `.edit.png` are what the model saw and returned),
`prop.png`/`with_prop.png`, `final.png`. Two or three Replicate calls,
~20–40 s each.

**Props.** The edges are a plain surface by design, so the join can land
on a stretch of nothing. The backdrop repeats every screen width, so pick
a prop that can plausibly recur that often — a tree, a parked van, crates
and barrels, a market stall, a column, a lamp cluster — never a one-off
(a sleigh, a monument, a named shop). `--prop "a parked delivery van"` generates that
object alone on a transparent background in the same style and hands it
to the seam repaint, which paints it standing on the painted ground at the
join with a contact shadow and matching light (`--prop-aspect 1536x1024`
for wide objects). The model does not honour a requested size well, so when the size
matters (`--prop-metres`) add `--prop-paste`: one more repaint without the
prop, then `paste_prop.py` stands it on the measured walk line at exactly
`--prop-height` (or the metres). `paste_prop.py --x` is also the tool for
dressing any other plain stretch of a backdrop.

**Replacing the world's backdrop:** the `sidescroller_world` prefab draws
`::sidescroller_world::spr_bg` at 2× into a 3200×1800 room. Generate the
new one as `spr_bg` with `--force` into `prefabs/sidescroller_world/sprites/spr_bg/`
(the prefab overlay — files there replace the prefab's) or into the project's
own sprites and point the world object's `bg_sprite` variable at it.

`--style` is the look; be concrete about era, medium and palette ("flat
cel-shaded", "painted", "pixel art", "dusk lighting"). Given no `--style`,
the project's `style.toml` supplies the last one used by any generating
skill, so a background made after a character follows the character's look.

## Options

| Flag | Default | Notes |
|---|---|---|
| `--size WxH` | `1600x900` | the fitted output; the generation itself is 2048×1152 |
| `--label TEXT` | none | stamps text over the middle (the placeholder art uses `REPLACE ME`) |
| `--seam auto\|always\|never` | `always` | `auto` repaints only when the seam ratio > 3 — it misses duplicated edge objects |
| `--prop TEXT` | none | one object, transparent background, stood over the seam |
| `--prop-aspect WxH` | `1024x1536` | the prop generation size; `1536x1024` for wide objects |
| `--px-per-m N` | `120` | scene scale; written as `[meta] px_per_m` |
| `--prop-metres M` | none | the prop's real height, so it is placed at `M × px_per_m` |
| `--prop-paste` | off | after the repaint has placed the prop (for the walk line), repaint the seam plain and paste the prop at its exact size instead |
| `--prop-height F` | `0.5` | `--prop-paste`: the prop's height as a fraction of the image height |
| `--quality low\|medium\|high` | `low` | `low` is fine for backdrops; `high` is ~3× slower |

## Reading the result

- **`seam ratio`** printed after fitting: the colour step across the wrap
  edge relative to an ordinary column step. ≤1.5 tiles invisibly, 2–3 is
  a faint line, >3 shows. It cannot see a *duplicated* object at the join
  (a lamp post at each edge tiles as two posts) — look at
  `final.png` beside a copy of itself, and if the join shows, regenerate.
- **A plain wall around the join**: the prompt asks for a narrow one on
  purpose and the crop trims what the model overdoes (`--plain`, 5% a side);
  `--prop` puts something in front of what is left.
- **The prop is lit wrong** (a daylit tree in a night scene): regenerate
  with the lighting in `--style` ("night, neon-lit"), or a different prop.
- **The ground line**: the template puts it at 73% of the height and the
  world prefab's `ground_frac` defaults to that, but the model usually paints
  the walkable surface a little lower. With `--prop` the driver measures it
  (`WALK LINE`); without, look at `final.png` and set `ground_frac` to where
  feet should go.
- **People or text in the picture**: the prompt forbids both, but the model
  slips. Regenerate — never ship a background with a stray figure, it will
  read as a character that doesn't move.
- **Perspective vanishing to the middle**: wrong for a side-scroller (the
  ground must be the same height across). Regenerate, adding "strictly
  straight-on side view" to the style.

## Common mistakes

- Generating at 1600×900 directly: gpt-image-2 only makes its own sizes;
  the script asks for 2048×1152 and cover-crops. Don't pass `--size` to
  change the generation.
- Fixing a seam by blurring/mirroring a strip in Pillow — it smears the
  middle of the level. The edit pass repaints it properly.
- Asking the prompt for a thin object at the edges (a pole, a tree): the
  two copies never line up and the repaint has to merge them. A wide plain
  surface tiles; put the interesting object in front with `--prop`.
- Forgetting `--force` when replacing an existing sprite name.
