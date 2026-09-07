#!/bin/sh
# Print the Blender executable, or explain how to install it and exit 1.
# Order: $BLENDER, `blender` on PATH, the macOS app bundle, common Linux paths.
if [ -n "$BLENDER" ] && [ -x "$BLENDER" ]; then echo "$BLENDER"; exit 0; fi
if command -v blender >/dev/null 2>&1; then command -v blender; exit 0; fi
for c in /Applications/Blender.app/Contents/MacOS/Blender \
         "$HOME/Applications/Blender.app/Contents/MacOS/Blender" \
         /usr/bin/blender /snap/bin/blender /opt/blender/blender; do
  if [ -x "$c" ]; then echo "$c"; exit 0; fi
done
cat >&2 <<'MSG'
Blender is not installed (looked at $BLENDER, PATH, /Applications/Blender.app).
Install it, then re-run:
  macOS : brew install --cask blender        (or https://www.blender.org/download/)
  Linux : snap install blender --classic     (or your distro's package)
Or point BLENDER at an existing executable:
  export BLENDER=/path/to/blender
MSG
exit 1
