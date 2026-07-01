# Accessible Archery

An **open-source, accessibility-first, Wii Sports-style archery game** — built so
that it can be played with whatever device a player uses, and built so that the
community (and their AI assistants) can extend it.

> Status: early scaffold / vertical slice. The core architecture is in place and
> playable; art, audio, content, and a settings UI are open work.

## The big idea

The whole game routes through **three abstract intents** — `aim`, `draw`,
`release`. Devices never talk to gameplay directly; each device has a small
**adapter** that produces those intents. That single decision is what makes the
game playable on a gamepad, a single switch, an Xbox Adaptive Controller,
eye-tracking, voice, or a device nobody has written support for yet.

```
Physical device → InputAdapter → intent (aim / draw / release) → gameplay
```

Adding support for a new device means writing one adapter. **Nothing in the
gameplay layer changes.** See [CONTRIBUTING.md](CONTRIBUTING.md).

## Running it

1. Install **Godot 4.3+** (standard build — no C#/.NET needed).
2. Open this folder as a project in Godot, or run from a terminal:
   ```
   godot --path .
   ```
3. Press **Play**.

### Try the accessibility thesis in 30 seconds

A 3D archery range with three targets. Press **1–5** to hot-swap the device and
play the *same game* every way:

- **1 — Keyboard:** aim with arrows/WASD, hold **Space** to charge, release to fire.
- **2 — Gamepad:** aim with the left stick, hold **A**.
- **3 — Single switch:** two-phase scan — tap **Space/A** to lock horizontal, tap
  to lock vertical, then it auto-fires. *The whole game with one input.*
- **4 — Eye tracking:** aim with your gaze (the mouse stands in for an eye
  tracker); hold your gaze still to draw; it auto-looses at full draw.
- **5 — Voice:** spoken commands (no mic? use the debug keys: arrows = aim,
  **Q** = draw, **E** = loose, **C** = center).
- Close your eyes in any mode: **audio cues** pan with aim and rise in pitch with charge.

## Project layout

| Path | What lives there |
|------|------------------|
| `scripts/input/` | The device-agnostic input layer (router + adapters) |
| `scripts/gameplay/` | Bow, arrow, target — pure game logic, no device knowledge |
| `scripts/accessibility/` | Assist settings + audio-cue system |
| `scripts/main.gd` | Vertical-slice wiring (placeholder, code-built scene) |
| `docs/ACCESSIBILITY.md` | The standards and design checklist we build against |
| `CLAUDE.md` | Orientation for AI coding assistants |

## License

- **Code:** [MIT](LICENSE) — do almost anything, just keep the notice.
- **Assets:** see [ASSET_LICENSES.md](ASSET_LICENSES.md) (CC-BY-4.0 / CC0 preferred).

Built by [Crystal Spider Games](mailto:benjamin@crystalspidergames.com).
