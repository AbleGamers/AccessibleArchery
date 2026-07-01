# Setup — getting the project running on another machine

This project is plain source (GDScript + text scenes). There is no build to copy
and nothing to compile. You just open the folder in Godot.

## Requirements

- **Godot 4.3 or newer**, the *standard* build (no C#/.NET/Mono build needed).
  Download: https://godotengine.org/download

## Open and run

1. Unzip `AccessibleArchery.zip` somewhere convenient.
2. Launch Godot. On the Project Manager, click **Import**.
3. Select the `project.godot` file inside the unzipped folder, then **Import & Edit**.
   - First open builds a local `.godot/` cache (a few seconds) — this is normal
     and is intentionally *not* shared between machines.
4. Press **Play** (▶, or F5).

## Try it (the 30-second tour)

A 3D archery range with three targets. Press **1–5** to hot-swap the input
device and play the same game every way:

| Key | Scheme | How to play |
|-----|--------|-------------|
| **1** | Keyboard | Aim arrows/WASD · hold **Space** to draw · release to fire |
| **2** | Gamepad | Aim left stick · hold **A** · release |
| **3** | Single switch | Tap **Space/A** to lock horizontal, tap to lock vertical, auto-fires |
| **4** | Eye tracking | Gaze aims (mouse stands in) · hold gaze still to draw · auto-fires |
| **5** | Voice | Debug keys: arrows aim · **Q** draw · **E** loose · **C** center |

Close your eyes in any mode — audio cues pan with aim and rise in pitch with charge.

## Moving work between machines (recommended: git)

For ongoing back-and-forth, use git instead of re-zipping:

```bash
# First machine — create the repo
cd AccessibleArchery
git init && git add . && git commit -m "Initial scaffold"
gh repo create AccessibleArchery --private --source=. --push

# Other machine — get it and keep it in sync
git clone <repo-url>
# ...then `git pull` / `git push` to move changes
```

The included `.gitignore` excludes Godot's `.godot/` cache, so you never sync
regenerated files or hit conflicts on them.

## Where to start reading

- `README.md` — what the project is and how it's structured.
- `CLAUDE.md` — the architecture in brief (good for AI assistants too).
- `CONTRIBUTING.md` — how to add support for a new device (write one adapter).
- `docs/ACCESSIBILITY.md` — the accessibility standard we build against.
