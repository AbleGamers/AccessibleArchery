# Blind / low-vision play — and the two-station booth

The game is fully playable **by ear**. This doc is the sound legend, the
recommended per-station settings, and a demo script for the booth format:

> **Station A** — a sighted player on a standard gamepad.
> **Station B** — a blindfolded player on a standard gamepad, playing entirely
> by audio. Same game, same rules, same scoreboard.

## The sound legend (teach this in 30 seconds)

| You hear | It means |
|---|---|
| **Panned ping, left/right** | Where the nearest target is, horizontally. Steer toward the sound until it's centred in your headphones. |
| **Ping gets higher and faster** | You're closing on the bullseye. |
| **A centred pair of notes in between the pings** | Your elevation is off — the up/down cue, kept **separate in time** so you never decode left/right and up/down at once. The pair **rises** → aim **up**; **falls** → aim **down**; sounds like one note when you're level. When your height is right the pairs stop and you just hear the panned ping. (Turn this off in the menu if you'd rather steer on the ping alone.) |
| **Bright shimmer on the ping** | You're in the gold. Loose it. |
| **Rising tone while holding draw** | Draw charge building (it wobbles if your aim is shaking). The targeting ping keeps going quietly underneath, so you can still hear where the target is — and the tone itself shimmers while you're on the gold. |
| **Quick two-tone chirp** | Full draw — you may release now. |
| **Soft ticking after the chirp** | Your held breath counting down. The ticks speed up and rise as it runs out — release before they get frantic. |
| **Crowd goes quiet** | You're drawing. The arena is holding its breath. |
| **Descending blip** | Draw cancelled (released before full draw) — nothing fired. |
| **Whoosh… thunk** | Arrow away… arrow landed. The thunk sits **where it struck the face**: left ear = left of centre, dead centre = both ears. A **ding** means gold (it sits there too). |
| **Spoken voice** | Score with the strike direction, archery-caller style ("Gold +9 — high left") — your correction for the next arrow. Also set results, "Steady — breath held", "Breath spent — sway rising!", wind shifts, match result, athlete names. |
| **Heavy rumble (controller)** | Breath spent — release soon or the shot degrades. |

### On the athlete select screen

The targeting ping goes quiet while the menu is up — the select screen owns the
soundstage:

| You hear | It means |
|---|---|
| **Spoken: "Choose your athlete…"** | The select screen just opened; it tells you who is highlighted and how to browse (steer, or just wait — the highlight moves on its own) and pick (draw). |
| **Short tick, panned + pitched** | The highlight moved. The tick sits where the card sits (left card = left ear) and its pitch rises left→right; the voice names each athlete. |
| **Rising three-note figure** | Your pick is locked in. The voice confirms it — draw when ready. |

A blindfolded end-to-end shot: *steer until the panned ping is centred and fast,
settle the up/down pairs into one note, listen for the shimmer, hold draw, wait
for the chirp, then release while the breath ticks are still slow.*

### Fine-tuning the sound (options menu → "Sound cue tuning")

Every value the cues use is a slider, not a hidden constant — tune them to your
ears, per station:

- **Guidance range (degrees)** — how far out the cues start reacting. Wider =
  the game guides you from further off the target.
- **Cue tempo** — how fast the beeps come at every distance.
- **Left/right** and **Up/down cue strength** — how aggressive each axis sounds;
  and **Up/down cue** can be switched off entirely.
- **Cue pitch low / high** — move the tones into a comfortable range (raise the
  low end or drop the high end for high-frequency hearing loss).
- **Aim cue while drawing** — how loud the ping stays under the draw tone, so you
  can still hear drift off the gold while at full draw.
- **Breath tick volume** — the release-window countdown, up loud or off.

## Recommended settings (Esc menu)

| Setting | Station A (sighted) | Station B (blindfolded) |
|---|---|---|
| Audio cues (sonified aim) | off (or on — it's subtle) | **on** |
| Spoken announcements (TTS) | off | **on** |
| Sound effects & crowd | on | on (the crowd auto-ducks during draws) |
| Haptic feedback | on | **on** (directional rumble = second nav channel) |
| Captions | on | on (for the audience!) |
| Aim sensitivity | default | **0.6–0.8** (slower = easier to stop on the ping) |
| Precision aim (slow near target) | default (0.65) | **0.7–0.8** — steering slows over the target, so overshooting the ping is much harder |
| Aim assist | 0 | 0.2–0.4 for first-timers, 0 for the brave |
| Wind strength | default | 0 for first-timers (one variable at a time) |
| Impact camera | on | on (the *audience* watches the arrow land) |

Settings persist per machine (`user://settings.json`), so configure each
station once. Both stations feed the same networked leaderboard, tagged with
the input badge.

## Setting up each station (once)

On first launch the game opens with a spoken **"How do you want to play?"**
screen. Configure each station once and it persists:

- **Station A** → **Standard**.
- **Station B** → **Audio-guided** (the blindfold mode — turns on the sonified
  aim, spoken announcements, and the gentler aim settings in one pick).

To change it later, press **Esc → "Change play style (guided presets)"**, or
tune individual rows in the same menu. For absolute first-timers on Station B,
drop Wind strength to 0 (one variable at a time). After setup, walk-up players
skip the play-style screen and go straight to athlete select.

## Booth demo script (Station B)

1. Hand over the gamepad, then the blindfold. Say: *"The beeping sound is the
   target. Steer left and right until it's dead centre in your headphones."*
2. *"Hear two quick notes? The second one is your height — make them one note."*
3. *"When the sound shimmers, you're on the gold. Hold A to draw — the beeps
   keep going quietly, so you'll hear if you drift off."*
4. *"The chirp means full power. Soft ticks are your breath running out — let
   go while they're still slow."*
5. The voice announces their score; the audience watches the impact cam. Most
   people hit the target within three arrows — that's the moment that sells
   the whole thesis.

Headphones on Station B are strongly recommended (stereo pan is the horizontal
cue). The Esc menu now has independent **Cue volume**, **SFX / crowd volume**,
and **Speech volume** sliders — for a loud venue, push cue and speech volume up
and pull crowd volume down on Station B specifically, rather than relying on
OS volume for the whole machine.

## Why this is trustworthy, not a gimmick

- Every cue is **redundant across senses** (sound ↔ caption ↔ haptic) — the
  Second Channel principle. TTS mirrors captions, so blind players get exactly
  what Deaf players get.
- The audio player competes under the **same rules**: same full-draw-only
  shots, same sway/breath window, same scoring. Nothing is simplified for
  them; the interface is simply different.
- All of it is procedural (`scripts/accessibility/audio_cue_system.gd`,
  `scripts/audio/sfx_system.gd`) — no audio assets, MIT-licensed, tweakable.
