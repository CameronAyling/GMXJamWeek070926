---
name: importing-rig-clips
description: Use when asked to add, import or create a new animation clip for the paper-doll rig characters in this gmx project from a Mixamo FBX file (a jump, a wave, a dance…) — FBX → Blender → posebox JSON → `clips/<name>/`
---

# Importing rig clips

## Overview

One command turns a Mixamo FBX (`Jump.fbx`) into a CLIP asset any rig in
the project can play: Blender imports the FBX headless into an empty scene,
posebox's exporter (vendored here, no add-on install) writes the skeleton +
animation as JSON, the bones are renumbered to gmx's template order so the
clip attaches to every rig, redundant keyframes are dropped, and `gmx new
clip --from` copies it in. Nothing is written by hand.

## When to use

- "add a jump / wave / dance clip from this FBX", "import this Mixamo animation"
- NOT for making a character (see generating-rig-characters) and NOT for
  editing an existing clip's markers (edit `clips/<name>/clip.toml`)

## Prerequisites

- **Blender** (any recent version; 4.x and 5.x tested). Probed from
  `$BLENDER`, `blender` on PATH, then `/Applications/Blender.app`. If it is
  missing the script stops and prints the install line — on macOS:
  `brew install --cask blender`. Ask the user before installing anything.
- `gmx` on PATH (or `GMX_BIN`), `python3`. Nothing else; no Replicate.
- A **Mixamo** FBX: the rig must be the 65-bone `mixamorig:` skeleton every
  gmx rig is fitted to. Download from mixamo.com on any character, "Without
  Skin" is fine (only the tracks are used). Other skeletons fail loudly.

## Run it

```sh
S=.claude/skills/importing-rig-clips/scripts
$S/make_clip.sh --project . --name clip_jump --fbx ~/Downloads/Jump.fbx
```

Result: `clips/clip_jump/clip.toml` + `clip.json`, project validated. Work
files in `~/.cache/gmx-clip-gen/<name>/`: `<name>.blend` (the import),
`<name>.skeleton.json` (the clip before it was copied in).

Name clips `clip_<verb>` (`clip_jump`, `clip_wave`) to match the ones the
character prefabs ship with. Then play it: `rig_set_clip(rig, clip_jump,
false, 0.2)` for a one-shot, `true` for a loop; `rig_clip_finished` tells
you when a one-shot is done.

## Stages (for running one by hand)

| Stage | Command | Notes |
|---|---|---|
| import | `$B -b --python $S/import-fbx.py -- in.fbx work/name.blend` | empty scene; exactly one armature or it exits; action renamed after the file |
| export | `$B -b work/name.blend --python $S/export-clip.py -- work/name.skeleton.json [--rot-eps 0.1]` | posebox JSON, bones renumbered to `assets/template.skeleton.json`, keyframes reduced |
| create | `gmx new clip NAME --from work/name.skeleton.json` | validates the JSON, writes `clip.toml` + `clip.json` |

## Reading the result

- **`BONES DIFFER … cannot reorder safely`**: not a Mixamo rig (bones absent
  or extra). Re-download the animation on a Mixamo character; do not try to
  rename bones by hand.
- **`expected exactly one armature, found N`**: the FBX carries a prop or a
  second rig. Re-export from Mixamo without the extra, or delete it in Blender.
- **`action : NONE`** in the import summary: the FBX has no animation (a
  T-pose download). Nothing to make a clip from.
- **Clip plays but the character slides / stays put**: Mixamo clips carry
  root motion in the hips track and gmx applies it by default
  (`rig_set_root_motion`). A clip downloaded "In Place" has none — either
  is fine, just know which you have.
- **Size**: the defaults keep ~60% of keys at sub-pixel error. Raise
  `--rot-eps` (degrees) if the JSON is too big for its purpose; 0.5 is still
  fine for a background character.
- **Get-up clips** need `rise` and `upright` markers in `clip.toml` for the
  ragdoll hand-off (see the character prefab). Add them by hand after import:
  ```toml
  [[marker]]
  name = "rise"
  time = 0.4
  ```

## Common mistakes

- Running the export against a `.blend` from Blender's UI with the default
  cube still in it — use `import-fbx.py`, which starts from an empty scene.
- Installing the posebox add-on into Blender: not needed, `export-clip.py`
  registers the vendored copy itself.
- Editing `clip.json` by hand; regenerate it instead.
