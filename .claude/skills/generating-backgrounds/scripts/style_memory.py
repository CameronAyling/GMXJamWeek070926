#!/usr/bin/env python3
"""The project's shared visual style, in `style.toml` at the project root.

usage: style_memory.py get PROJECT                  -> prints the style, or exits 1 with a message
       style_memory.py set PROJECT "STYLE" --by SKILL --for NAME
Every generating-* skill calls `set` after a generation and `get` when the user
gives no style, so a project's backgrounds, characters and props stay in one look."""
import argparse, os, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("op", choices=["get", "set"])
ap.add_argument("project")
ap.add_argument("style", nargs="?")
ap.add_argument("--by", default="?")
ap.add_argument("--for", dest="for_", default="?")
a = ap.parse_args()
path = os.path.join(a.project, "style.toml")


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def current():
    if not os.path.exists(path):
        return None
    for line in open(path):
        line = line.strip()
        if line.startswith("style ="):
            v = line.split("=", 1)[1].strip()
            return v[1:-1].replace('\\"', '"').replace("\\\\", "\\") if v.startswith('"') else v
    return None


if a.op == "get":
    s = current()
    if not s:
        sys.exit("no style.toml in the project yet: pass --style (the first generation sets the project's look)")
    print(s)
else:
    if not a.style:
        sys.exit("set needs a style")
    hist = ""
    if os.path.exists(path):
        body = open(path).read()
        i = body.find("[[history]]")
        hist = body[i:] if i >= 0 else ""
    stamp = time.strftime("%Y-%m-%d %H:%M")
    entry = f'[[history]]\nwhen = "{stamp}"\nskill = "{esc(a.by)}"\nresource = "{esc(a.for_)}"\nstyle = "{esc(a.style)}"\n\n'
    open(path, "w").write(
        "# The project's visual style, kept by the generating-* skills (backgrounds,\n"
        "# rig characters, sprites). `style` is the look the NEXT generation follows\n"
        "# when the user names none; edit it freely. History is newest first.\n\n"
        f'style = "{esc(a.style)}"\n\n' + entry + hist
    )
    print(f"STYLE {path}: {a.style}")
