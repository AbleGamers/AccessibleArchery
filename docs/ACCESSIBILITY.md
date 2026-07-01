# Accessibility — design standard & checklist

Accessibility is the **core design pillar** of this game: it must be playable by
disabled gamers using the devices they already use. This document is the
standard every contribution is measured against.

## Reference standards

- **[Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/)** —
  our primary checklist (Basic / Intermediate / Advanced tiers).
- **[Xbox Accessibility Guidelines (XAGs)](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines)** —
  concrete, testable criteria.
- Consider playtesting with **[AbleGamers](https://ablegamers.org/)** or
  **[SpecialEffect](https://www.specialeffect.org/)** — real disabled-gamer
  feedback is the gold standard (and great for an OSS title's credibility).

## Input — the foundation

- [x] Device-agnostic intent layer (`aim_axis` / `aim_absolute` / `draw` / `release`).
- [x] Single-switch complete play loop, two-phase scan (the accessibility floor — never break it).
- [x] Eye-tracking adapter (gaze + dwell, auto-release; hardware-cursor compatible).
- [x] Voice adapter (command API + keyboard debug bridge; pluggable recognizer).
- [x] Xbox Adaptive Controller works via the standard gamepad adapter.
- [x] Adjustable aim sensitivity (`AssistSettings.aim_sensitivity`).
- [x] Input actions registered in code, ready for remapping.
- [ ] Runtime remapping UI.
- [ ] Head-tracking, sip-and-puff adapters.
- [ ] Real speech-recognition backend wired to the voice adapter.
- [ ] Hold-vs-toggle option for the draw action.

## Motor

- [x] No required simultaneous inputs.
- [x] `unlimited_time` — no time pressure by default.
- [x] Graduated aim assist (`AssistSettings.aim_assist`).
- [x] Adjustable draw time (`full_draw_seconds`).
- [ ] Adjustable input sensitivity / dwell time per device.

## Vision

- [x] Audio cues for aim (pan) and charge (pitch) — playable without sight.
- [x] Adjustable target size (`target_size_scale`).
- [ ] Colorblind-safe palettes / high-contrast mode.
- [ ] Scalable UI / text size.
- [ ] Full screen-reader support in menus.

## Hearing

- [ ] Captions/subtitles for all meaningful audio.
- [ ] Visual equivalents for every audio cue.

## Cognitive

- [x] Minimal, single-action core loop.
- [ ] Simple mode + clear, redundant feedback.
- [ ] No reading required to play.

## Definition of done for any feature

A change is not complete until it is still fully playable via **single switch**
**and** via **audio-only**, with no new required simultaneous inputs.
