# Booth launch scripts

Double-click shortcuts for the three booth roles (station / server / display),
per `docs/BOOTH_ARCHITECTURE.md`. These are thin wrappers around CLI flags —
see that doc for what each role does.

**No export/build step.** These scripts run the project directly through the
Godot editor executable (`godot4 --path <project> -- <flags>`) instead of a
compiled export — same trick used throughout `docs/BOOTH_ARCHITECTURE.md`'s
own testing. That skips export presets, export templates, and code signing
entirely; the whole "deployment" is copying two folders.

## Folder layout each machine needs

```
<any folder>/
  Godot.app          (macOS) or  Godot.exe + its files  (Windows)
  AccessibleArchery/  <- this whole project (contains this booth/ folder)
```

`Godot.app`/`Godot.exe` must sit **next to** the `AccessibleArchery` project
folder — the scripts look one level up from `booth/`, then one more level up,
to find it. If a machine already has Godot 4 installed system-wide instead,
the scripts fall back to that automatically (`godot4`/`godot` on PATH) — no
need to bundle Godot on that machine too.

## One-time setup (per machine, before a con)

1. Copy `Godot.app` (macOS) or the Godot 4 folder (Windows) and the whole
   `AccessibleArchery` project folder into the same parent folder, per the
   layout above. USB drive is fine.
2. On macOS, the first double-click of a `.command` file may need
   **right-click → Open** once (Gatekeeper), same as any unsigned/downloaded
   app — do this once per script, per machine, ahead of the con.
3. **Launch each script once as a test**, ahead of time, not for the first
   time on con morning. The very first run on a machine does a one-time
   import (`.godot/` cache) that takes a few seconds; better to hit that
   delay during setup than in front of a visitor.

No per-machine rebuild, ever — the same project folder runs the station,
server, or display depending only on which script you double-click.

## Which script on which machine

- **Station 1** and **Station 2**: `start-station` on each play-station PC.
- **Back machine**: both `start-server` AND `start-display`, on the one PC
  that also drives the big monitor.

See `docs/BOOTH_RUNBOOK.md` for the staff-facing one-page guide.

## Optional: a compiled build instead

If you'd rather ship a single app (no Godot editor on the machine), export
presets are checked in (`export_presets.cfg`, macOS + Windows). One-time on the
dev machine: install the matching export templates (Godot editor → *Editor →
Manage Export Templates → Download and Install*), then:

```sh
godot --headless --export-release "macOS"   build/AccessibleArchery-macos.app
godot --headless --export-release "Windows" build/windows/AccessibleArchery.exe
```

**The same binary is every role** — the role is picked by the flags after the
`--` separator, exactly like the scripts above:

```sh
# macOS (the binary inside the .app is named "Accessible Archery" — mind the quotes)
"build/AccessibleArchery-macos.app/Contents/MacOS/Accessible Archery" -- --station --kiosk
"build/AccessibleArchery-macos.app/Contents/MacOS/Accessible Archery" -- --display
"build/AccessibleArchery-macos.app/Contents/MacOS/Accessible Archery" -- --server

:: Windows (make one .lnk or .bat per role on each machine)
AccessibleArchery.exe -- --station --kiosk
AccessibleArchery.exe -- --display
AccessibleArchery.exe -- --server
```

Caveats:
- The **Voice scheme's** out-of-process bridge (`tools/voice_bridge.py` +
  `models/`) is not inside the export — copy those folders next to the build
  on a machine that demos voice, or skip voice there. Every other scheme
  (including the AT Bridge) is fully self-contained.
- macOS builds are ad-hoc signed: first launch on a new machine needs the
  usual **right-click → Open** once.
- Settings/leaderboard live in `user://` either way, so switching between the
  editor-run and exported-run flow keeps every machine's configuration.
