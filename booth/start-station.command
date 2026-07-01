#!/bin/bash
# Double-click to launch this machine as a play station.
# No export/build needed — runs the project directly through Godot.
# Expects Godot.app to sit next to the AccessibleArchery project folder
# (see booth/README.md), or Godot installed on this machine already.

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLED_GODOT="$DIR/../Godot.app/Contents/MacOS/Godot"

if [ -x "$BUNDLED_GODOT" ]; then
	GODOT="$BUNDLED_GODOT"
elif command -v godot4 >/dev/null 2>&1; then
	GODOT="godot4"
elif command -v godot >/dev/null 2>&1; then
	GODOT="godot"
else
	echo "Godot wasn't found."
	echo "Put Godot.app next to the AccessibleArchery folder, or install Godot 4 on this machine."
	read -p "Press Enter to close..."
	exit 1
fi

"$GODOT" --path "$DIR" -- --station --kiosk
