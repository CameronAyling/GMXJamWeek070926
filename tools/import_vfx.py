"""Import the curated combat VFX frame animations.

    python tools/import_vfx.py        (needs Pillow)

Two sources, two shapes on disk:

  PACK   the Postie-Pocalypse effects pack — loose numbered PNGs per effect,
         numbered without zero padding (`..._2.png`, `..._10.png`), so they
         need a natural sort rather than a lexical one.
  ANIME  a GameMaker project — PNGs named by GUID, with the playback order
         only recorded in the sprite's `.yy`. Read the order from there.

Each effect is resampled to its own max dimension and written as a gmx sprite
with a centred origin, so draw code positions by the impact point.

Re-runnable: swap a source below and re-run to restyle an effect.
"""
import os
import re
import json
import glob
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = r"C:\Users\lroddam\Desktop\Postie-Pocalypse\vfx"
ANIME = r"C:\Users\lroddam\GameMakerProjects\Anime_VFX_Tests\sprites"

# sprite name -> (source kind, path within that source, max dimension in px)
EFFECTS = {
    # Ballistic and energy hits.
    "Spr_Vfx_Impact":   ("anime", "spr_knife_terrain_hit", 128),
    "Spr_Vfx_Shock":    ("anime", "spr_electricity_arc",   160),
    "Spr_Vfx_Acid":     ("pack",  r"Explosions\Slime_Explosion", 128),

    # Firing.
    "Spr_Vfx_Muzzle":   ("anime", "spr_muzzle_flash", 128),
    "Spr_Vfx_GunSmoke": ("anime", "spr_gun_smoke",     96),

    # Destruction.
    "Spr_Vfx_Blast":    ("anime", "spr_enemy_death", 208),
    "Spr_Vfx_Puff":     ("anime", "spr_ground_land", 160),

    # Persistent / ambient.
    "Spr_Vfx_Flame":    ("anime", "spr_torch_fire",   64),
    "Spr_Vfx_Dust":     ("anime", "spr_running_dust", 96),
    "Spr_Vfx_Smoke":    ("pack",  r"Smoke\Plumes_Of_Smoke", 128),
}

TOML = "#:schema ../../.gm-schema/v1.json#sprite\norigin = \"centre\"\n"


def frame_no(path):
    m = re.search(r"_(\d+)\.png$", os.path.basename(path))
    return int(m.group(1)) if m else 0


def pack_frames(sub):
    src = os.path.join(PACK, sub)
    return sorted(glob.glob(os.path.join(src, "*.png")), key=frame_no)


def anime_frames(sub):
    """Playback order lives in the .yy, not the filenames (they are GUIDs)."""
    src = os.path.join(ANIME, sub)
    yy = os.path.join(src, sub + ".yy")
    raw = open(yy, encoding="utf-8-sig").read()
    raw = re.sub(r",(\s*[}\]])", r"\1", raw)        # .yy allows trailing commas
    data = json.loads(raw)
    return [os.path.join(src, f["name"] + ".png") for f in data["frames"]]


def main():
    for name, (kind, sub, max_dim) in EFFECTS.items():
        frames = pack_frames(sub) if kind == "pack" else anime_frames(sub)
        frames = [f for f in frames if os.path.exists(f)]
        if not frames:
            raise SystemExit(f"no frames found for {name} ({kind}: {sub})")

        dst = os.path.join(ROOT, "sprites", name)
        os.makedirs(dst, exist_ok=True)
        # Clear stale frames, so a shorter source cannot leave a gap in the run.
        for old in glob.glob(os.path.join(dst, "frame_*.png")):
            os.remove(old)

        size = None
        for i, f in enumerate(frames):
            im = Image.open(f).convert("RGBA")
            if size is None:
                k = max_dim / max(im.size)
                size = (max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k)))
            im.resize(size, Image.LANCZOS).save(os.path.join(dst, f"frame_{i:03d}.png"))

        with open(os.path.join(dst, "sprite.toml"), "w", encoding="utf-8") as fh:
            fh.write(TOML)
        print(f"{name:20s} {kind:5s} {len(frames):3d} frames  {size[0]}x{size[1]}")


main()
