# Accessible Archery — Game Design Document

The reference design for the project. Code comments that say "per the GDD"
mean this file. It describes **intent**; the code map and conventions live in
`CLAUDE.md`, and per-topic depth lives in the other docs
(`ACCESSIBILITY.md`, `BLIND_PLAY.md`, `AT_BRIDGE.md`, `VOICE.md`,
`BOOTH_*.md`).

---

## 1. Concept

A Wii-Sports-style **3D Olympic archery** game that is **accessibility-first**:
playable by disabled gamers on whatever device they already use — gamepad,
keyboard, a single switch, eye tracking, voice, or any assistive interface via
a UDP bridge — and fully playable **without sight**, by ear alone.

- **Genre**: arcade sports (target archery, World Archery rules flavor).
- **Engine**: Godot 4, GDScript, zero third-party assets (everything is built
  in code; MIT + CC-BY only).
- **Session length**: one match ≈ 3–5 minutes. Designed for booths/events:
  walk up, pick an athlete, shoot a match, bank a score.
- **Thesis**: accessibility is the *core mechanic*, not a settings page. Every
  player competes under the **same rules** on the **same leaderboard**; only
  the interface differs.

## 2. Design pillars

1. **Same game for every body.** One shared aim envelope, full-draw-only
   shots, identical scoring. No device or assist grants (or costs) power —
   assists trade *challenge*, never *rules*.
2. **The Second Channel.** Every critical cue is broadcast on **three senses
   at once** — sight (HUD/captions), sound (tones/TTS), touch (haptics). You
   can win by sight, sound, OR touch; no single sense is required.
3. **Input is intents, not devices.** Gameplay consumes abstract intents
   (aim, draw, release, steady). Supporting a new device is one adapter file;
   gameplay never changes.
4. **Single-switch is the floor.** If a feature can't be driven by one button
   (via scanning/auto behaviors), it doesn't ship.
5. **Dignity, not simplification.** Assisted players are never given a "baby
   mode" — the interface adapts, the sport stays the sport.

## 3. The core loop

```
(first run: choose play style) → select athlete →
    AIM → DRAW → (full draw) STEADY → RELEASE → score → next arrow
```

### 3.0 First-run setup — "How do you want to play?"

Accessibility is worthless if a player can't find it, and the hardest case is
the bootstrap: a blind player launches a silent visual menu and is stuck at
frame one. So the **first interactive screen speaks**, and it is a
**play-style preset picker** (`scripts/ui/playstyle_select.gd`), shown before
athlete select:

- **Standard** — play by sight (cues off, captions + rumble on).
- **Audio-guided** — play by ear, no screen needed (the blindfold mode: cues +
  TTS on, gentler sensitivity/precision, light aim assist).
- **Low-motion & forgiving** — big targets, steady aim, no timer, static
  camera (low vision / tremor / motion sensitivity).
- **One switch** — pins single-switch input with forgiving assists.

Each is a **bundle** in `scripts/accessibility/play_presets.gd` that writes a
whole set of `AssistSettings` at once — the discoverability fix for "how do I
even turn blind play on?" A preset is orthogonal to the input **device** (only
"One switch" pins the scheme); the game **auto-detects a connected gamepad** on
first launch so the device is rarely a manual choice. The picker uses the same
intents, spoken navigation, auto-scan and panned ticks as athlete select, so
every device — including a single switch, eyes-free — can operate it.

It is shown **once** (`AssistSettings.setup_complete`), then skipped on later
launches; players reopen it from the options menu ("Change play style"). At a
booth each station is configured once and walk-up players go straight to
athlete select — the station's preset persists, so Station B stays audio-guided
without re-selection.

### 3.1 Aim

- The bow has one shared envelope: **±55° yaw, ±32° pitch**, identical for
  every device and athlete.
- Two intent forms, consumed transparently:
  - `aim_axis` — rate steering (keyboard, stick, voice nudges), fixed base
    rate 55°/s × `aim_sensitivity`. Stick magnitude is deliberately ignored:
    an analog stick must not out-aim a key.
  - `aim_absolute` — point-to-aim (eye tracking, switch scan, reticle), maps
    [-1, 1] to the envelope directly.
- **Precision zone** (fine control): rate steering slows as the aim closes on
  a target — within a 12° cone, speed scales down by up to
  `precision_slowdown` (default 0.65) at dead centre. Coarse sweeps stay
  fast; the last few degrees are fine. Device-agnostic, so parity holds.
- **Aim assist** (optional, 0–1): the loosed arrow's direction lerps toward
  the target the player is aiming nearest. An onboarding/motor-access aid.

### 3.2 Draw

- Hold the draw intent to charge; full draw takes `full_draw_seconds`
  (default 1.2 s).
- **Full-draw-only shots**: releasing before ~full charge *cancels* (with
  distinct feedback on all three channels). There are no weak arrows —
  a switch player's auto-loosed shot and a pro's timed release are the same
  arrow. This is the fairness keystone.
- `toggle_draw` (tap to draw, tap to loose) removes sustained muscle strain.

### 3.3 Sway & steady (the skill expression)

- While drawing, the reticle **sways** with tension (amplitude ∝ charge,
  scaled by `sway_scale`; 0 = perfectly steady, the accessibility floor).
  Sway moves only the bow arm — **never the camera** (motion comfort).
- At full draw, **held breath snaps the aim steady** for `breath_seconds`
  (default 2.5 s): sway is exactly zero, so releasing anywhere in the window
  is a true shot. Auto-hold is the default; a manual `steady` intent exists
  for devices that can express it, and devices that can't always get
  auto-hold — nobody is disadvantaged.
- **Over-holding** past the breath brings sway back, growing wider and faster
  the longer you hang on. Risk/reward: greedy centering vs. a degrading hold.
  `unlimited_time` removes the clock entirely.

### 3.4 Release & flight

- Every arrow launches at full power; gravity plus **wind** (lateral drift,
  scaled by `wind_scale`, announced on all channels) shapes the flight.
- Arrows stick where they land. An optional broadcast-style **impact cam**
  (hard cuts, no swooping) shows the strike; off = the camera never leaves
  the shoulder.

### 3.5 Scoring & match

- **World Archery 10-ring face**: 10 equal bands, 10 points innermost;
  face size scales with `target_size_scale`.
- **Olympic set play** vs. a CPU whose accuracy ramps as the match goes:
  3 arrows per set; set winner takes 2 set points (1 each on a tie); first
  to 6 set points; 6–6 goes to a single-arrow sudden-death shootout.
- Cumulative ring points can be **banked to the leaderboard** under a player
  name, tagged with an input-scheme badge (⌨ 🎮 🕹 👁 🎙 🔌) — the badge
  celebrates *how* you played, the number competes as an equal.

## 4. Input architecture (the one rule)

```
device → InputAdapter (scripts/input/*) → InputRouter (autoload) → gameplay
```

Gameplay never polls `Input.*` and never names a device. Intents: **aim**
(axis or absolute), **draw**, **release**, optional **steady**.

| Scheme | Aim | Draw / loose | Notes |
|---|---|---|---|
| Keyboard / mouse | arrows/WASD (rate) | hold/tap Space | Shift = steady |
| Gamepad | left stick (rate, magnitude ignored) | hold/tap A | X = steady; XAC enumerates as a gamepad |
| Single switch | two-phase scan: tap locks horizontal, tap locks vertical | auto-fires at full draw | **the accessibility floor** |
| Eye tracking | gaze = absolute aim | dwell to draw, auto-loose | mouse stands in without hardware |
| Voice | stepped nudge commands | "draw" / "loose" | debug key bridge for testing |
| AT bridge | UDP :9010 datagrams, any of the above | any | universal protocol, `docs/AT_BRIDGE.md` |

All actions are code-registered and **remappable** in-game — much assistive
hardware presents as "a keyboard that types one unusual key".

## 5. The Second Channel (accessibility model)

Every critical cue exists in all three columns; any one column is sufficient
to play and win.

| Cue | Sight | Sound | Touch |
|---|---|---|---|
| Where is the target? | reticle on the aim line | panned ping (side + rate/pitch = closeness), with a separate-in-time centred pair for up/down when elevation is off | directional rumble, stronger off-centre |
| On the gold | reticle over gold | octave shimmer on ping (and on the draw tone) | rumble fades to calm |
| Draw charge | string/arrow pull-back, % HUD | rising tone (keeps the ping quietly underneath) | — |
| Full draw | screen flash | two-tone chirp | sharp pulse |
| Steady window | breath % HUD | soft metronome ticks, faster + higher as breath runs out | — |
| Breath spent | caption | spoken warning + tone wobble | long rough rumble |
| Draw cancelled | caption | descending blip | soft low buzz |
| Shot result | impact cam, stuck arrow | panned thunk at strike point; spoken score + correction ("Gold +9 — high left") | — |
| Wind | always-on arrow + km/h | spoken shifts | light constant rumble ∝ speed |
| Menus (athlete select) | highlighted card | panned+pitched tick per move, spoken names, rising confirm figure | — |

Principles:

- **TTS mirrors captions** — blind players get exactly what Deaf players get.
- **Information vs. atmosphere**: cue audio (`AudioCueSystem`) and crowd/SFX
  (`SfxSystem`) are separate toggles; the crowd auto-ducks during a draw so
  ambience can never mask a cue.
- **Menus own the soundstage**: while a UI captures input, the targeting ping
  is silent and the same instrument serves the interface.
- All sound is **procedural** (no assets), so the full legend
  (`docs/BLIND_PLAY.md`) is tweakable in code.

## 6. Athletes

Four playable athletes, wheelchair users first-class — visual identity and
shooting height only, **identical aim envelope**, never a stat:

| Athlete | Discipline |
|---|---|
| MAYA | Standing · Recurve |
| LEO | Standing · Composite |
| ANA | Wheelchair · Recurve |
| KAI | Wheelchair · Composite |

The select screen is driven by the same intents as gameplay (browse by
steering, absolute aim, hover, or just wait — it auto-scans; any draw intent
confirms) and is fully spoken for blind play.

## 7. Presentation

- **Look**: clean low-poly outdoor tournament meadow — a "festival field"
  archery range (rolling grass, tree line and hills, tents, flag-lined lanes,
  bleachers + crowd, earth-berm backstop, scaffold LED screen), everything
  generated in code. Third-person over-the-shoulder rig; camera side is
  flippable (handedness/eye dominance). Ambient scenery is static (no swaying
  trees or flapping flags) so the Low-motion preset stays honest.
- **Sound identity**: procedural whoosh/thunk/crowd/fanfare — atmosphere
  only; everything it reacts to is also captioned.
- **Broadcast dressing**: scoreboard overlay, optional second-monitor
  scoreboard window, impact cam, big-screen match state.

## 8. Booth / event mode

The flagship demo is a **two-station booth** (see `docs/BLIND_PLAY.md` and
`docs/BOOTH_RUNBOOK.md`):

- **Station A** — sighted player, standard gamepad, "Standard" preset.
- **Station B** — blindfolded player, same gamepad, "Audio-guided" preset:
  guided entirely by audio (headphones): spoken play-style pick → spoken
  athlete select → ping-guided aim → chirp → breath ticks → spoken score. Same
  rules, same shared networked leaderboard.
- Each station's preset is chosen **once** on first launch (or from the options
  menu) and persists, so throughput isn't slowed by re-picking; the picker is a
  one-time setup, not a per-player gate.
- **Attract mode**: idle stations run a self-playing demo; the first real
  input on any device resets to the athlete select for the next player.
- Kiosk deployment, exe-first launchers, and recovery live in the booth docs.

## 9. Tuning & settings

Every difficulty/accessibility tunable lives in `AssistSettings` (autoload,
persisted to `user://settings.json`, live-updating via the Esc menu) — never
as inline magic numbers:

| Setting | Default | What it trades |
|---|---|---|
| `aim_sensitivity` | 1.0 | steering speed (tremor / range-of-motion aid) |
| `precision_slowdown` | 0.65 | fine control near the target (0 = constant speed) |
| `aim_assist` | 0.0 | arrow magnetism toward the worked target |
| `target_size_scale` | 1.0 | face size |
| `sway_scale` | 1.0 | aim wobble; 0 = rock steady (the floor) |
| `breath_seconds` | 2.5 | steady release window |
| `full_draw_seconds` | 1.2 | charge time / auto-loose timing |
| `unlimited_time` | off | removes the over-hold clock |
| `auto_hold_breath` | on | steady without a second input |
| `toggle_draw` | off | tap-tap instead of hold (strain) |
| `wind_enabled` / `wind_scale` | on / 1.0 | flight variable |
| `audio_cues_enabled` / `cue_volume` | on / 1.0 | sonified aim/draw (the blind-play channel) |
| `sfx_enabled` / `sfx_volume` | on / 1.0 | atmosphere, separate from information |
| `captions_enabled` / `tts_enabled` / `tts_volume` | on / on / 100 | the visual/spoken mirrors |
| `haptics_enabled` | on | the touch channel |
| `impact_cam_enabled` | on | reduce-motion option |
| `camera_on_left` | on | framing side |
| `guidance_cone_deg` | 12 | how far off target the cues + precision zone react (shared) |
| `cue_tempo` / `pan_strength` | 1.0 / 4.0 | ping speed; how hard the stereo swings |
| `elevation_cue_enabled` / `elevation_interval` | on / 0.75 | the separate-in-time up/down beat and its pitch spread |
| `cue_pitch_low` / `cue_pitch_high` | 220 / 880 Hz | tone range (hearing comfort) |
| `aim_cue_while_drawing` / `breath_tick_volume` | 0.5 / 1.0 | ping level under the draw tone; steady-countdown ticks |

Guideline for new features: if it changes difficulty or perception, it gets a
row here (a var in `AssistSettings`), a control in the options menu, and a
presence on all three Second-Channel columns. The **sound cues are fully
player-tunable** — no value that shapes how a tone feels is a hidden constant;
it is an `AssistSettings` field with a slider, so a player configures the
guidance to their own ears.

## 10. Out of scope (for now) / roadmap

- Authored art scenes replacing the code-built environment (architecture
  already allows it).
- Local two-player alternating match (two stations already race on the
  leaderboard).
- More adapters: head tracking, sip-and-puff (templates exist).
- Richer sonification: distance voicing, wind-in-the-ears panning.
- Practice/tutorial range with spoken coaching.

## 11. Non-negotiables (ship gates)

1. Single-switch can reach **every** interactive surface, including menus.
2. A blindfolded tester can complete athlete select → three scored arrows
   using audio only.
3. No gameplay file references a device; no `Input.*` outside adapters.
4. Every new critical cue lands on all three channels before merge.
5. MIT + CC-BY assets only; everything redistributable.
