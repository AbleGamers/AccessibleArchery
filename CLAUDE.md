# CLAUDE.md

Orientation for AI coding assistants (and humans skimming for the mental model).

## What this is

An open-source, accessibility-first, Wii Sports-style **3D** archery game in
**Godot 4 (GDScript)**. The defining requirement: it must be playable by
disabled gamers using whatever device they already use. Accessibility is the
core design pillar, not a setting.

## The one architectural rule

Input is fully decoupled from gameplay through abstract intents: **aim (axis or
absolute), draw, release**, plus an optional **steady** (hold-breath) intent —
devices that can't express it (see `InputAdapter.supports_steady()`) get
auto-hold behaviour from the controller, so no device is disadvantaged.

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
| `scripts/input/*_adapter.gd` | Keyboard, gamepad, single-switch (two-phase scan), eye-tracking (gaze + dwell), voice (command API + debug bridge), AT bridge (universal UDP protocol, `docs/AT_BRIDGE.md`). Templates for more. |
| `scripts/accessibility/assist_settings.gd` | Autoload `AssistSettings`. Aim sensitivity/assist, target scale, audio toggle, active scheme, etc. All tunables live here. |
| `scripts/accessibility/audio_cue_system.gd` | Procedural audio cues for sightless play: pan = left/right, two-note ping = elevation, shimmer = gold cone, chirp = full draw, pitch = charge. Legend: `docs/BLIND_PLAY.md`. |
| `scripts/accessibility/second_channel_hud.gd` | Captions + wind + draw-snap flash; captions are also SPOKEN via OS TTS (`AssistSettings.tts_enabled`). |
| `scripts/gameplay/archery_controller.gd` | The bow (`Node3D` + `Camera3D`). Consumes intents, applies aim assist, fires arrows. |
| `scripts/gameplay/arrow.gd` / `target.gd` | 3D projectile + Olympic 10-ring scoring, meshes built in code. Arrows stick where they land. |
| `scripts/gameplay/impact_cam.gd` | Broadcast-style target cam for each shot (hard cuts, no swooping). Disabled via `AssistSettings.impact_cam_enabled`. |
| `scripts/gameplay/athlete_roster.gd` | The four playable athletes (2 standing, 2 wheelchair), built in code. Visuals + shooting height only — identical aim envelope. |
| `scripts/ui/character_select.gd` | Athlete select overlay. Navigable by every scheme via the same intents (`InputRouter.captured_by_ui`), incl. auto-scan for single switch. |
| `scripts/audio/sfx_system.gd` | Procedural sound identity (whoosh, thunk, crowd, fanfare). Atmosphere only — everything it reacts to is captioned elsewhere. |
| `scripts/booth/attract_mode.gd` | Idle → self-running auto-demo; first real input on any device resets the station to the athlete select. |
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
