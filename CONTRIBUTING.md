# Contributing

Thanks for helping make archery playable for everyone. This project is designed
to be extended — by humans and by AI coding assistants alike.

## Ground rules

1. **Accessibility is the product, not a feature.** Every change should keep (or
   improve) playability across devices and abilities. See
   [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md).
2. **Never hardcode a device into gameplay.** Gameplay listens to intents
   (`aim` / `draw` / `release`) from `InputRouter` — nothing else.
3. **No non-redistributable assets.** Anything you add must be license-clean for
   an open-source repo (see [ASSET_LICENSES.md](ASSET_LICENSES.md)). This
   includes AI-generated art/audio — check the generator's terms.

## The most valuable contribution: a new device adapter

Want to support a head tracker, a sip-and-puff switch, voice control, an eye
tracker, a MIDI foot controller, a custom rig? You only need to write an
adapter.

1. Add `AssistSettings.InputScheme.YOUR_DEVICE` to
   `scripts/accessibility/assist_settings.gd` (and a label in `scheme_label()`).
2. Create `scripts/input/your_device_adapter.gd`:

   ```gdscript
   extends InputAdapter
   class_name YourDeviceAdapter

   func _init() -> void:
       scheme = AssistSettings.InputScheme.YOUR_DEVICE

   func _process(_delta: float) -> void:
       if not _is_active():
           return
       # Translate your device's raw input into intents. Pick the aim style
       # that matches your device:
       InputRouter.report_aim_axis(self, steering_vector)      # rate (keys/stick)
       #   ...or...
       InputRouter.report_aim_absolute(self, point_in_minus1_to_1)  # point-to-aim
       InputRouter.report_draw_pressed(self)                   # begin draw
       InputRouter.report_draw_released(self)                  # loose
   ```

   Use **`report_aim_axis`** for devices that steer over time (keyboard, stick,
   "turn left" voice command). Use **`report_aim_absolute`** for devices that
   point directly (eye tracking, switch scanning, a reticle). The controller
   handles both. See `eye_tracking_adapter.gd`, `voice_adapter.gd`, and
   `single_switch_adapter.gd` as worked examples.

3. Register it in `InputRouter._ready()` (or ship it as a plugin).

That's it. The bow, arrow, scoring, and audio cues all work with your device
immediately, because they only ever see intents.

## Code conventions

- GDScript, tabs for indentation, `snake_case` files and functions.
- Prefer small, single-responsibility scripts with a doc comment (`##`) at the
  top explaining *why* the file exists.
- Keep gameplay logic free of `Input.*` calls — that belongs in adapters.

## Working with an AI assistant

This repo is structured to be AI-legible — text scenes, small modules, and a
[CLAUDE.md](CLAUDE.md) orientation file. If you use Claude Code or similar, point
it at `CLAUDE.md` first.
