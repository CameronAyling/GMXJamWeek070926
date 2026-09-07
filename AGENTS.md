> **Generated with gmx version 0.4.8 (g87a996db2f2e).** If `gmx --version` is newer,
> ask the user whether to run `gmx refresh` to update this file.

This is a GameMaker project in TOML form. `gmx` is the CLI; the `*.toml`
and `*.gml` files in this tree are the source of truth, never write `.yy`
or `.yyp`!

Global flags: `--json` (often more terse), `--verbose` (to debug issues), `--quiet`.
Most commands that take a project accept any of: a directory (project.toml or a single .yyp), a `.yyp`
file, a `.yyz`/`.tomlz` archive, an HTTP(S) URL, or a prefab reference.

## Key commands (see --help for complete list)

```
gmx build [project]              Just build and produce a .wad.
gmx run [project]                build + launch game
gmx run . --timeout n            Timeout after n seconds. Use for any non-interactive workflow!
gmx run . --headless             Windowless game
gmx run . --screenshot s.png --at-frame 2,60,120 See 'gmx test' for more advanced use.
gmx run . --wasm                 run a (WASM) web build in browser
gmx test <t.gametest.json> [--project .]
                                 deterministic headless test: build, run,
                                 assert; exits 0 iff passed. See "gmx test --help" for more details.
                                 Useful when encountering issues or wanting to take screenshots at specific moments.
gmx debug                        For more advanced debugging
gmx validate [project]           schema + load + GML compile checks. Use after making changes to code or TOML files.
gmx tools rename <old> <new> [--project .]
                                 rename a resource and propagate changes
gmx tools sprite-info <name> [--project .]
                                 pixel size, frame count, origin of a sprite
gmx import <yyp|yyz> <target>    ingest a GameMaker IDE project
gmx new <kind> <name> [--project .]
                                 scaffold a TOML resource. kinds: object,
                                 script, room, sprite, sound, font, shader,
                                 tileset, path, sequence, particle-system,
                                 animation-curve, rig, clip, instance.
gmx new instance <room> <obj>    append a placed instance to the room's
                                 instances layer (--x/--y, --layer); id
                                 generated for you

```

Build/run/test also take `--runtime gms2[@<version>]` (default) or
`--runtime gmrt[@<version>]`.

Reference for GML built-ins **and** the gmx-authored toolchain pages
(events, variables, layers, scripts, prefab-spec, vk_constants,
getting-started, common-gml-patterns):

```
gmx docs lookup <name>
gmx docs search <words...>
gmx docs list --json
```

**Recipes are the canonical "how do I build X" implementations.** Before
generating GML or scaffolding objects from scratch for a common feature
(title screen, pause menu, audio, room transitions, state machines, custom
cursor, …), check `gmx docs list --kind recipe` first and follow a match
verbatim — recipes encode details (compression modes, persistence patterns,
input event choices, frame-rate independence) that are easy to get wrong
from first principles. `gmx docs lookup anatomy-of-a-complete-game` shows
how they compose.

## Prefabs (reusable assets from a catalog)

A **catalog** is a git repo whose `prefabs/<name>/` directories each hold a
prefab, discovered via git tags (`<name>@<version>`). Commands default to the
`gh:opera-gaming/prefabs` catalog; override with `--catalog gh:<user>/<repo>`
(the only catalog form).

```
gmx prefab list [--tag t] [--category c]
gmx prefab search <q> [--kind sprite]     free-text over resources
gmx prefab show <prefab>                  manifest + resource list
gmx prefab tags
gmx prefab add <ref> [--project <dir>]    add a prefab or one resource
gmx prefab sync --project <dir>           re-resolve linked prefabs' caches. Automatically done before build/run.
```

**A ref is either a whole prefab or a single resource inside one:**

```
<prefab>                     a whole prefab   (e.g. iconic_animals)
<prefab>/<kind>/<name>       one resource     (e.g. iconic_animals/sprites/spr_cat)
gh:<user>/<repo>/<prefab>…   full form, names the catalog explicitly
…@<version>                  pin a version   (omit for the latest)
```

- `gmx prefab add <prefab>` writes `prefabs/<prefab>/link.toml` (a pinned
  source); an implicit `sync` resolves it into a gitignored `.cache/`.
  Add `--vendor` to materialise the full resolved tree in place instead.
- `gmx prefab add <prefab>/<kind>/<name>` vendors just that one resource
  into `prefabs/<prefab>/<kind>/<name>` and writes a minimal
  `prefabs/<prefab>/prefab.toml` so the resource is **namespaced**. Add
  `--centre-origin` to set `origin = "centre"` on vendored sprite(s)
  (gameplay usually wants this; catalog sprites often ship `top_left`).

**Worked example — grab a background + a player sprite and wire them up:**

```
gmx prefab add space_rocks_hd/sprites/spr_sky_nebula1
gmx prefab add iconic_animals/sprites/spr_cartoon_cat_ginger --centre-origin
gmx new room rm_main --background "::space_rocks_hd::spr_sky_nebula1"
gmx new object obj_player --sprite "::iconic_animals::spr_cartoon_cat_ginger"
gmx new instance rm_main obj_player --x 960 --y 540
# then author objects/obj_player/Step.gml for arrow-key movement
gmx validate .
```

(Catalogs change — `gmx prefab list`/`search` to see what yours has,
`gmx prefab show <prefab>` for resource names. `add` prints the exact
`::ns::resource` ref to paste into TOML/GML.)

**Discovering ready-made behaviour.** Some prefabs are effectively libraries
— drop-in GML for common effects (screen shake, flashes, room transitions).
Prefer them over hand-rolling: discover with `gmx prefab list` and
`gmx prefab search <effect>`, then `gmx prefab show <prefab>` for its API
before writing your own.

**Prefab sprites usually need per-use adjustment.** Catalog assets are
original artwork with no canonical in-game size or facing:

- **Scale** — often 256–1024px, rarely gameplay-sized. Prefer to resize image over scaling at runtime.
- **Rotation** — no library-wide facing convention. Check the first frame and
  set `image_angle` in `Create.gml` if it doesn't match your gameplay axis.
- **Origin** — gameplay code assumes centred. Check the imported
  `sprite.toml` or pass `--centre-origin` to `add`.

**Patching a linked prefab.** A linked prefab keeps its pinned `source` in
`prefabs/<prefab>/link.toml` and resolves into a gitignored
`prefabs/<prefab>/.cache/`. Never edit `.cache/` — **overlay** instead: a
file under `prefabs/<prefab>/` at a resolved file's relative path wins over
the source. Copy a file out of `.cache/` to the matching path and edit the
copy _in full_ (`*.toml` copies replace the source wholesale, so carry every
field you want kept). To drop an inherited file/resource, add its path to
`unset` in `link.toml`:

```toml
source = "gh:opera-gaming/prefabs/cam_shake@1.2.0"
unset  = ["sprites/spr_legacy"]
```

Sync runs automatically before validate/build/run, or manually with
`gmx prefab sync --project .`. Track overlay files and `link.toml` in git;
`--vendor` takes full local ownership (no `link.toml`).

To author your own prefab: `gmx init --prefab <dir>` (see that scaffold's
AGENTS.md for authoring and publishing).

## Referencing prefab resources: `::prefab::resource`

A prefab added under `prefabs/<prefab>/` is namespaced: refer to any
resource inside it with `::<prefab>::<resource>`. **The same spelling works
in TOML and GML**:

```toml
# objects/obj_x/object.toml
sprite = "::camera_shake::spr_asteroid"
```

```gml
draw_sprite(::camera_shake::spr_asteroid, 0, x, y);
::camera_shake::camera_shake(0.5, 0.1, 0.1, 0.1);  // call a prefab function
```

## Browser editor (`gmx editor`)

`gmx editor` serves a browser-based editor for the project. The URL accepts
`?resource=<name>` to open a resource as soon as the project loads: a plain
resource name, or the namespaced `::prefab::resource` form for a resource
of an added prefab. An absent or unknown name starts the play view instead
(the in-browser game).

## Project layout

```
.gm-schema/v1.json            JSON schema for every TOML file
project.toml                  schema_version, name, [room_order]
sprites/<name>/
  sprite.toml                 optional — omit for an all-default sprite
  frame_000.png               first frame (PNG/JPEG), or one frame_000.svg
  frame_001.png               (more frames as needed)
objects/<name>/
  object.toml
  Create.gml                  event scripts (one per event)
  Step.gml
  Draw.gml
rooms/<name>/
  room.toml
  layers/
    Instances.toml
    Background.toml
    Tiles.toml
    Assets.toml
sounds/<name>/
  sound.toml                  optional
  source.<wav|mp3|ogg>
scripts/<name>/
  <name>.gml                  the whole asset — there is no script.toml
shaders/<name>/
  vertex.vsh                  required
  fragment.fsh                required
  shader.toml                 optional — no configuration
fonts/<name>/
  font.toml                   mode = "frozen": sibling atlas.png + glyphs.toml.
                              mode = "ttf": sibling source.ttf (literal name),
                              rasterised at compile time; size required
```

## Editing rules

- Every TOML's first line is a schema definition. Preserve it.
- `frame_NNN.png` filenames are positional (zero-padded) — don't rename; to
  reorder frames, change which file holds which bytes. A sprite may be a
  single vector `frame_000.svg` (tessellated at build). JPEG frames decode
  to opaque RGBA and may mix with PNG.
- Room layers: `depth = N` decides render z-order AND on-disk order (sorted
  depth-ascending at load). The layer's name in `instance_create_layer(...)`
  is the file stem (`Instances.toml` → `"Instances"`). Background layers
  stash their body under a `[background]` table. Full reference:
  `gmx docs lookup layers --category gmx`.
- Room order: `[room_order].order` in `project.toml` — the first entry is
  the starting room. Optional: with one room, omit it. The **first room's
  `size`** sets the window dimensions. `window_set_fullscreen()` /
  `window_set_size()` have no reliable effect under `gmx run`'s dev runner —
  don't chase workarounds; `gmx docs lookup window-fullscreen --category gmx`.
- Object event filenames have a strict grammar. `gmx init` ships the
  **native** form (`Create.gml`), `gmx import` the **imported** form
  (`Create_0.gml`). Match the project; grammar at
  `gmx docs lookup events --category gmx`.
- Shaders are GLSL ES, defaulting to **ES 1.00**; make `#version 300 es` the
  first line for ES 3.00. **Match the project's existing shaders**; prefer
  ES 3.00 when the project/runner supports it. `gmx docs lookup shaders
--category gmx`.
- **Never draw text with the default font** (`draw_set_font(-1)`) — it's a
  tiny bitmap. Create a sized font asset and draw at scale 1.
- **Keep texture smoothing on.** The scaffolded `obj_main` enables filtered,
  mipmapped, anisotropic sampling once at boot (`gpu_set_tex_filter(true)`,
  `gpu_set_tex_mip_enable(mip_on)`, `gpu_set_tex_mip_filter(tf_anisotropic)`,
  `gpu_set_tex_max_aniso(16)`) — scaled and rotated art shimmers and
  pixelates without it. If you replace `obj_main`, carry the block into your
  own boot object; drop it only as a conscious choice, for crisp pixel art.
- Object-scope `[[variables]]` and the always-string room-instance override
  gotcha: `gmx docs lookup variables --category gmx`.

## Room authoring — prefer placed instances over code-spawn

Avoid blank rooms where actors spawn in `Other_RoomStart.gml` via
`instance_create_layer` — that makes rooms invisible to human editors.
Prefer placing instances and backgrounds as real layer entries
(`kind = "instances"` / `kind = "background"`); reserve code-spawn for
genuinely dynamic content. `gmx docs lookup layers --category gmx`.

## Terrain — tile layers drawn as a shape

Terrain is a `kind = "tiles"` layer with an `[autotile]` block. You describe
the terrain as `#` (filled) / `.` (empty) and gmx picks every tile index;
`legend` and `map` in the layer file are generated from it, so edit the shape
and re-run rather than the indices.

```
gmx autotile shape <room>/<layer>            print the shape, axes numbered
gmx autotile shape <layer> --map-size 30x17  size it, in tiles
gmx autotile shape <layer> --op 'rect 4,6 12,8 clear'
gmx autotile apply <room>                    redraw from the shape
gmx autotile check                           audit tables and committed maps
```

What each subcommand is for:

| | |
|---|---|
| `identify` / `derive` | say what a sheet is, and build its mask table |
| `explain` / `sample` | what the table can draw, as text or a rendered PNG |
| `shape` / `apply` | author terrain, and redraw it |
| `check` / `coverage` | audit what is committed, and what a shape never used |
| `set-tile` / `rm-set` | correct one mask by hand; drop a set |

The table comes from the catalog or from `gmx autotile derive <ts>`, which
picks the layout itself when given no flags. Check it by eye —
`gmx autotile sample <ts> --render /tmp/t.png --tile-size 32` — since no audit
reads the art, so a table can be complete and still wrong.

GameMaker's 16-tile template is a *corner* set: its shape is the lattice
between tiles, so an H×W shape yields an (H-1)×(W-1) map. `--map-size` states
the size in tiles and does that arithmetic for you.

Tiles that are not terrain — decorations, hazards, the tiles a blob set does
not model — go through `gmx tools room-tiles <layer> --set ROW,COL=TILE`
(repeatable, one write; `--size WxH` creates the grid, `0` clears a cell,
`ROW,COL=<brush>` stamps a `[[brushes]]` group).

Reference: `gmx docs lookup autotile --category gmx`.

## Physics shapes (declarative)

`[physics.body.shape]` in `object.toml` handles every Box2D fixture case —
no `bind_*_fixture` / `physics_fixture_set_*` calls in `Create.gml`.

Variants: `circle`, `aabb`, `polygon`, `edge`, `wire` (passthrough escape
hatch). `polygon` accepts any simple polygon — the compiler decomposes to
fit Box2D's 32-vertex convex limit. `edge` is one segment via
`from`/`to = [x, y]`. Every variant supports `scale = "instance"`: the
runner multiplies vertices by `image_xscale`/`image_yscale` and reverses
winding for negative-on-one-axis scale.

Points are in sprite-top-left coordinates; the runner subtracts the sprite's
origin before handing vertices to Box2D. Spriteless objects (`edge`
barriers) use body-local coords. Full reference with examples:
`gmx docs lookup physics-shapes --category gmx`.

## Build-time TOML references in GML (`::path`)

GML references TOML values as compile-time literals via `::`:

```gml
// resolves against the current object's TOML:
drag_hull   = ::physics.body.shape.points;
my_sprite   = ::sprite;

// cross-resource form names another resource:
ball_origin = spr_ball::custom_origin;
game_name   = project::name;
```

Project-wide constants live in a `[constants]` table in `project.toml`,
read with `project::constants.<key>`:

```gml
url = project::constants.server_url;
```

Constants bake into the compiled game — **not** hot-reloadable. For
live-tweakable values use `global.<foo>` or an instance variable.

## Human-AI workflow

When you write or change code, the loop is:

1. **You make the change, run `gmx validate .`.**
2. **Hand to the human — they run `gmx run .` and play the game.**

The human is the one who experiences the result. Don't block them with your own
`gmx run --headless` or `gmx test` calls unless they explicitly ask you to.
`gmx validate .` is enough to catch schema, loader, and compile errors.

If the human reports something is broken or asks you to debug, _then_ reach for
`gmx run --headless --timeout <secs>` or `gmx test`.

When a flagged pattern is genuinely intentional, silence that line with a trailing
`//gmx-lint-ignore <code>` (bare = all codes on the line / next line).

Side note: the Mac runner prints unconditional `NSLog` lines before any game
code (`Nil context detected`, `!!!!######## rendersize=…`) — cosmetic,
not warnings.

## How we talk

When explaining anything to a human, the agent should sound like a game-jam buddy
who's built a few games and is showing you the ropes. The goal: make the human
feel like they're making progress, not reading a reference manual.

- **Be brief.** A few words beats a paragraph. If you can explain it in one sentence,
  do it. Humans scrolling through a terminal window do not want essays.
- **Lead with what they'll see.** Not what the command does — what appears on screen.
  "Run `gmx run` and your cat will stroll around the room." not
  "Builds the project and launches the native runner."
- **Explain why, not just how.** If a step matters to the end result, say why in one
  sentence. Skip the rest.
- **Build momentum.** Celebrate wins and keep the next step obvious. Don't let them
  sit on a command without telling them what to do next.
- **One thing at a time.** Don't dump five options. Give the path, mention alternatives
  only when they actually need them.
- **Be honest about time.** If a command takes 10 seconds, say so. If the runner
  prints noise before the game starts, warn them so they don't sit staring at a
  frozen terminal wondering if it hung.
- **Format links as markdown.** Never dump a raw URL — always use `[readable text](url)`.
- **Frame discoveries as shared exploration.** "Try changing `speed = 4` to `6` and
  run again — notice how much snappier it feels?" not "You may modify the speed
  variable to alter movement."

What to avoid:

- Essays when a sentence works. If you find yourself writing three paragraphs to
  explain a command, you're wrong.
- Dry technical dumps. Reference commands (gmx docs lookup, gmx schema) are fine
  as-is; don't dress them up, but don't lead with them.
- Anxiety language. "Traps", "never", "must" — they make building feel dangerous.
  "Watch out for this" or "you'll save yourself a headache if" land better.
- Explaining the wrong audience's problems. Don't warn about view cameras or
  persistent objects unless the human's code actually triggers them.
- Tutorial-speak. No "Congratulations! You completed the first lesson!" It's cringe.
- Raw URLs. If a link needs to appear, format it as `[description](url)` every time.

## Debugging and driving a running game

`gmx debug` inspects and _modifies_ a running game from the CLI. Verbs
target the current directory by default; `--project <dir>` otherwise.

**Prefer headless verification.** Default to `gmx debug start --headless`,
`gmx run --headless`, `gmx test` (always headless). A windowed runner left
on screen absorbs the user's stray clicks/keys into the debug-input channel
and corrupts your readings. Only run windowed when the user plays the game.

**Discrete steps (most tasks): per-verb `--json`.** One command → one JSON
envelope → decide the next:

```
gmx debug start --headless        # build --debug, launch windowless, attach
gmx debug bp set objects/obj_player/Step.gml:14
gmx debug continue
gmx debug wait --timeout 5 --json
gmx debug describe --json         # state, location, stacks, globals, log tail
gmx debug eval 'global.score' --json
gmx debug stop
```

See `gmx debug --help` for more details.

## Common runtime traps

These produce a game that validates and builds clean but renders empty or
wrong on launch:

- **A non-persistent object's `Create` runs again on every room entry.**
  `room_goto` rebuilds the next room fresh. Which fix you want depends on
  the variable, and the two cases are opposites:
  - _Carry-over_ state (lives, score, unlocks) must survive transitions —
    a bare `global.lives = 3;` silently resets it every time. Guard it
    (`if (!variable_global_exists("lives")) global.lives = 3;`), set
    `persistent = true`, or initialise it in an object only in the first
    room.
  - _Per-run_ state must reset at the start of a run — the `Create`
    re-running IS the reset mechanism; guarding it there makes run two
    start with run one's score. Assign unconditionally.
- **`enable_views = true` in `room.toml`** turns on the view-camera system;
  without per-view `camera_*`/`viewport_*` fields the runtime renders
  nothing visible. Leave it unset unless you need cameras.
- **Gating `Step` is not a pause.** The engine keeps advancing
  `speed`/`direction` motion, counting alarms, and animating sprites
  (`image_index` advances outside your code). To pause fully, also zero the
  motion, stash-and-clear alarms, and set `image_speed = 0`.
- **A tile layer draws but does not collide.** Sample it with
  `tilemap_get_at_pixel` and test the raw result for `< 0` *before*
  `tile_get_index`, or the mask turns -1 into a large valid-looking index.
- **Transparent sprite on a Background layer** shows framebuffer garbage
  through the alpha. Add a second `Background.toml` at a HIGHER `depth`
  (drawn first) with `[background] colour = "#0a0014"` (any opaque colour).

## If stuck

- Read sibling files of the same kind for the expected shape.
- `gmx schema` lists every queryable kind; `gmx schema <query>` prints its
  JSON-schema definition (`object`, `sprite`, `room`, `layer`, `font`, …).
- `gmx docs lookup <name>` covers GML built-ins **and** the first-party gmx
  pages; `gmx docs list --category gmx` for the toolchain set;
  `gmx docs lookup getting-started --category gmx` for a walkthrough.
- `gmx prefab show <prefab>` lists a catalog prefab's resources;
  `gmx prefab search <q>` finds assets to reuse.

## Version Control

Note that the user has git installed on PATH.

## Notes

<!-- gmx:notes:begin -->
Add project-specific notes below this marker. `gmx refresh` regenerates everything above it from the installed gmx's template but never touches anything from the marker to the end of the file.
