# CLAUDE.md

Orientation for AI coding assistants (and humans skimming for the mental model).

## What this is

An open-source, accessibility-first, Wii Sports-style **3D** archery game in
**Godot 4 (GDScript)**. The defining requirement: it must be playable by
disabled gamers using whatever device they already use. Accessibility is the
core design pillar, not a setting.

## The one architectural rule

Input is fully decoupled from gameplay through abstract intents: **aim (axis or
absolute), draw, release**.

```
device → InputAdapter (scripts/input/*) → InputRouter (autoload) → gameplay
```

- **Never** put `Input.*` polling in gameplay scripts. It belongs in an adapter.
- **Never** reference a specific device in `scripts/gameplay/`.
- Supporting a new device = one new `InputAdapter` subclass. Nothing else moves.

### Two aim intents

- `aim_axis(Vector2)` — continuous steering, integrated over time. Rate devices:
  keyboard, gamepad stick, stepped voice commands.
- `aim_absolute(Vector2)` — point-to-aim, components in [-1, 1], set directly.
  Pointing devices: eye tracking, single-switch scan, reticle.

The `ArcheryController` (a `Node3D` with a child `Camera3D`) consumes both and
maintains yaw/pitch.

## Map

| File | Role |
|------|------|
| `scripts/input/input_router.gd` | Autoload `InputRouter`. Registers input actions in code, owns adapters, emits `aim_changed` / `draw_pressed` / `draw_released`. |
| `scripts/input/input_adapter.gd` | Base class `InputAdapter` (+ `_is_active()`). |
| `scripts/input/*_adapter.gd` | Keyboard, gamepad, single-switch (two-phase scan), eye-tracking (gaze + dwell), voice (command API + debug bridge). Templates for more. |
| `scripts/accessibility/assist_settings.gd` | Autoload `AssistSettings`. Aim sensitivity/assist, target scale, audio toggle, active scheme, etc. All tunables live here. |
| `scripts/accessibility/audio_cue_system.gd` | Procedural audio cues (pan = aim, pitch = charge) for sightless play. |
| `scripts/gameplay/archery_controller.gd` | The bow (`Node3D` + `Camera3D`). Consumes intents, applies aim assist, fires arrows. |
| `scripts/gameplay/arrow.gd` / `target.gd` | 3D projectile + scoring, meshes built in code. |
| `scripts/main.gd` | 3D range wiring, environment built in code (placeholder for authored scenes). |

## Conventions

- GDScript, **tabs** for indent, `snake_case`.
- Top-of-file `##` doc comment explaining why the file exists.
- Tunables that affect difficulty/accessibility go in `AssistSettings`, never as
  inline magic numbers.

## Good next tasks

- A settings/accessibility menu UI that writes to `AssistSettings`.
- New device adapters (eye tracking, head tracking, voice, sip-and-puff).
- Replace the code-built slice with real 2D or 3D scenes (architecture unchanged).
- Richer audio cues (verticality, distance, wind) and full captioning.
- Runtime input remapping UI (the input map is already code-registered).

## Don't

- Don't add Asset Store / non-redistributable assets (this is MIT + CC-BY).
- Don't break single-switch playability — it's the accessibility floor.
