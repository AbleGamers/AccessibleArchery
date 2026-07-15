#!/bin/bash
# Assemble the Windows booth package: everything a booth PC needs, in one
# folder, ready to copy to a USB stick. Run from anywhere:
#
#   bash booth/make-windows-package.sh
#
# Prerequisite: the Windows export exists (Project > Export, or:
#   godot --headless --export-release "Windows" build/windows/AccessibleArchery.exe)
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="$PROJECT/build/windows/AccessibleArchery.exe"
OUT="$PROJECT/build/AccessibleArchery-booth-windows"

if [ ! -f "$EXE" ]; then
	echo "ERROR: $EXE not found — export the Windows build first." >&2
	exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$EXE" "$OUT/"
cp "$PROJECT/booth/start-station.bat" "$OUT/"
cp "$PROJECT/booth/start-server.bat" "$OUT/"
cp "$PROJECT/booth/start-display.bat" "$OUT/"
cp "$PROJECT/docs/BOOTH_CLICK_GUIDE.md" "$OUT/READ ME FIRST - which icon to click.md"
cp "$PROJECT/docs/BOOTH_RUNBOOK.md" "$OUT/RUNBOOK - setup and troubleshooting.md"
cp "$PROJECT/docs/PLAYER_GUIDE.md" "$OUT/PLAYER GUIDE - print me.md" 2>/dev/null || true

( cd "$PROJECT/build" && rm -f AccessibleArchery-booth-windows.zip \
	&& zip -rq AccessibleArchery-booth-windows.zip AccessibleArchery-booth-windows )

echo "Package folder: $OUT"
echo "Zip for USB:    $PROJECT/build/AccessibleArchery-booth-windows.zip"
