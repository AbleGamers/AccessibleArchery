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
