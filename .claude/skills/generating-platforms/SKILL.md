---
name: generating-platforms
description: Use when asked to create or generate a platform, ledge, walkway, beam or floating floor piece sprite for this gmx project that can be stretched to any width — AI-generated on a transparent background and written as a three-slice (nine-slice) sprite with a repeating centre
---

# Generating platforms

## Overview

One command turns "a riveted steel walkway" into a sprite `obj_wall` (the
sidescroller_world prefab's static box) can draw at any width. The trick that
makes the middle repeat cleanly is the one the backgrounds skill uses for its
wrap seam: `openai/gpt-image-2` paints one wide platform with finished ends and
a uniform middle, and `slice_platform.py` searches the middle for the pair of
columns that match best — the repeating centre runs between them, so where it
wraps, the join is two columns that already look alike. Whatever lies outside
that pair is the two caps. The sprite ships with nine-slice guides (top and
bottom 0, centre `repeat`), so the runtime does the stretching.

## When to use

- "make a platform / ledge / walkway / girder I can stretch", "platform art
  for the level", "platforms that match the background"
- NOT for full backgrounds (generating-backgrounds) or props that do not
  stretch (generating-sprites)

## Run it

```sh
export REPLICATE_API_TOKEN=…     # Replicate billing
# needs: gmx on PATH (or GMX_BIN), python3 with Pillow

S=.claude/skills/generating-platforms/scripts
$S/make_platform.sh --project . --name spr_platform_steel \
  --style "a riveted steel fire-escape walkway, neon city night" \
  --reference sprites/spr_bg_city/frame_000.png     # the scene to match; optional
```

- `--height PX` — the sprite's height (default 64). Pick it for the scene's
  scale (`px_per_m`): a walkway is ~0.3 m thick.
- Without `--style` the project's `style.toml` (kept by every generating-*
  skill) is used, so platforms come out in the level's look.
- `--force` replaces a sprite of that name in place.

It prints the caps' widths and a `SEAM` ratio (wrap step over an ordinary
column step; ~1 is invisible, above ~3 generate again), and writes
`preview.png` showing the platform at three widths — **look at it** before
using the sprite.

## Use it in the world

`obj_wall` (sidescroller_world) draws `platform_sprite` stretched over its box:

```toml
[[entries]]
object = "::sidescroller_world::obj_wall"
x = 1200
y = 1400
scale_x = 600.0          # the platform's width
scale_y = 64.0           # = the sprite's height
overrides = [{ name = "platform_sprite", value = "spr_platform_steel" }]
```

The box is the collider; its top is the surface characters stand on, so keep
`scale_y` equal to the sprite's height and paint platforms whose top edge is
the walkable surface.

## Files

- `scripts/make_platform.sh` — the driver
- `scripts/gen_platform.py` — the generation (`assets/prompt-platform.txt`)
- `scripts/slice_platform.py` — trim, find the caps and centre, scale, preview
- `scripts/replicate_api.py`, `scripts/style_memory.py` — shared helpers
