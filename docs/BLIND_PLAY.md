# Blind / low-vision play — and the two-station booth

The game is fully playable **by ear**. This doc is the sound legend, the
recommended per-station settings, and a demo script for the booth format:

> **Station A** — a sighted player on a standard gamepad.
> **Station B** — a blindfolded player on a standard gamepad, playing entirely
> by audio. Same game, same rules, same scoreboard.

## The sound legend (teach this in 30 seconds)

| You hear | It means |
|---|---|
| **Repeating ping, panned left/right** | Where the nearest target is. Steer toward the sound until it's centred. |
| **Ping gets higher and faster** | You're closing on the bullseye. |
| **A second note after each ping** | Your elevation is off: second note **higher** → aim **up**; **lower** → aim **down**. Make the two notes **one**. |
| **Bright shimmer on the ping** | You're in the gold. Loose it. |
| **Rising tone while holding draw** | Draw charge building (it wobbles if your aim is shaking). |
| **Quick two-tone chirp** | Full draw — you may release now. |
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

A blindfolded end-to-end shot: *steer until the ping is centred and fast, merge
the two notes, listen for the shimmer, hold draw, wait for the chirp, release
before the voice warns about breath.*

## Recommended settings (Esc menu)

| Setting | Station A (sighted) | Station B (blindfolded) |
|---|---|---|
| Audio cues (sonified aim) | off (or on — it's subtle) | **on** |
| Spoken announcements (TTS) | off | **on** |
| Sound effects & crowd | on | on (the crowd auto-ducks during draws) |
| Haptic feedback | on | **on** (directional rumble = second nav channel) |
| Captions | on | on (for the audience!) |
| Aim sensitivity | default | **0.6–0.8** (slower = easier to stop on the ping) |
| Aim assist | 0 | 0.2–0.4 for first-timers, 0 for the brave |
| Wind strength | default | 0 for first-timers (one variable at a time) |
| Impact camera | on | on (the *audience* watches the arrow land) |

Settings persist per machine (`user://settings.json`), so configure each
station once. Both stations feed the same networked leaderboard, tagged with
the input badge.

## Booth demo script (Station B)

1. Hand over the gamepad, then the blindfold. Say: *"The beeping sound is the
   target. Steer left and right until it's dead centre in your headphones."*
2. *"Hear two quick notes? The second one is your height — make them one note."*
3. *"When the sound shimmers, you're on the gold. Hold A to draw."*
4. *"The chirp means full power. Let go."*
5. The voice announces their score; the audience watches the impact cam. Most
   people hit the target within three arrows — that's the moment that sells
   the whole thesis.

Headphones on Station B are strongly recommended (stereo pan is the horizontal
cue). If the venue is loud, raise the OS volume rather than the in-game mix —
the cue/SFX balance is tuned to keep the pings above the crowd.

## Why this is trustworthy, not a gimmick

- Every cue is **redundant across senses** (sound ↔ caption ↔ haptic) — the
  Second Channel principle. TTS mirrors captions, so blind players get exactly
  what Deaf players get.
- The audio player competes under the **same rules**: same full-draw-only
  shots, same sway/breath window, same scoring. Nothing is simplified for
  them; the interface is simply different.
- All of it is procedural (`scripts/accessibility/audio_cue_system.gd`,
  `scripts/audio/sfx_system.gd`) — no audio assets, MIT-licensed, tweakable.
