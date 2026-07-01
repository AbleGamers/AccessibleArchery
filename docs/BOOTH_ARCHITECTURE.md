# Convention Booth Architecture — Networked Leaderboard

**Status:** All six build-order milestones implemented (server + score
submission; display attract-mode kiosk with input-method badges; UDP
auto-discovery with a manual-IP/timeout fallback; offline outbox +
auto-reconnect; daily rollover with TODAY/BEST OF SHOW boards +
archive/backup files; CLI-flag launcher + kiosk lockdown + staff runbook).
See `scripts/net/`, `scripts/boot.gd`, `booth/`, `docs/BOOTH_RUNBOOK.md`, and
`docs/BOOTH_CLICK_GUIDE.md` (exactly which icon to click on which machine —
hand this one to staff). Deployment deliberately skips exporting a compiled
binary — the `booth/` scripts run the project directly through the Godot
editor executable (`godot4 --path <project> -- <flags>`), so setup is
"copy Godot + the project folder together," no export presets/templates/
signing ever needed. Not yet done: real hardware validation (everything here
is tested with multiple local processes, not physical booth hardware — see
the milestone-3 discovery caveat below) and the still-open name-policy
decision (#5 below). This document is a self-contained brief so a fresh
session (human or AI) can pick up from here without prior context.

## Why this exists

Accessible Archery is being shown by the **AbleGamers** nonprofit at conventions.
The booth setup we want:

- **Two play stations** — two separate computers, each running the game, so two
  visitors play at once.
- **One back-of-booth leaderboard monitor** — a large display facing the aisle so
  people walking by see live scores and get drawn in.
- Scores from **both** stations flow into **one shared leaderboard** shown on that
  back monitor.

The mission angle matters: the leaderboard should visibly celebrate that people
win with **whatever input works for them** (voice, switch, eye-tracking, keyboard,
gamepad). See "Input-method badges" below — it is the point, not a nice-to-have.

## Guiding principles (already true of this codebase — keep them)

- **Input never changes gameplay.** Device = control scheme only; the arrow,
  power, scoring are identical across devices. Don't let networking break this.
- **No art/asset dependencies.** Everything is built in code. Keep the display
  kiosk the same way (or introduce assets deliberately, documented).
- **Local-first, offline-capable.** Convention WiFi is unreliable — the whole
  system runs on a private LAN with **no internet dependency**.
- **One codebase, multiple roles.** Do not fork the project per machine.

---

## Current state (what already exists)

Godot **4.7** project, pure GDScript, standard (non-.NET) build. Autoloads (in
`project.godot`, load order matters): `AssistSettings`, `Wind`, `InputRouter`,
`Leaderboard`.

Relevant to this feature:

| Piece | File | Notes |
|---|---|---|
| Leaderboard store | `scripts/leaderboard/leaderboard_store.gd` (autoload `Leaderboard`) | Top-10, persists to `user://leaderboard.json`. API: `add_score(name, score)`, `top(n)`, signal `updated`, `clear()`. **This is the seam to split into client/server.** |
| Second-monitor window | `scripts/leaderboard/scoreboard_window.gd` (`ScoreboardWindow`) | Native OS window; fills screen 2 if present. |
| In-window overlay | `scripts/ui/scoreboard_panel.gd` (`ScoreboardPanel`) | Top-right overlay, toggled by B. |
| Broadcast overlay | `scripts/ui/broadcast_scoreboard.gd` (`BroadcastScoreboard`) | Top-left You/CPU match panel. |
| Settings (persisted) | `scripts/accessibility/assist_settings.gd` (autoload `AssistSettings`) | Persists to `user://settings.json`. Has `player_name`, `input_scheme` + `scheme_label()`. |
| Name entry | `scripts/ui/name_prompt.gd` (`NamePrompt`) | Prompt on first bank; name stored in `AssistSettings.player_name`. |
| Options menu | `scripts/ui/options_menu.gd` (`OptionsMenu`) | Esc to open; all accessibility toggles + player name. |
| Match flow | `scripts/match/match_manager.gd` (`MatchManager`) | Sets/points/CPU. |
| Entry point | `scripts/main.gd` | Banks score via `_do_bank()` → `Leaderboard.add_score(player_name, _score)` on **L**. |

**Key fact for this feature:** the active input device is already known at all
times via `AssistSettings.input_scheme` and `AssistSettings.scheme_label()`. So
tagging each score with the input method used is essentially free.

`user://` on macOS resolves to
`~/Library/Application Support/Godot/app_userdata/Accessible Archery/`.

**Not yet built:** any networking. Today each machine's leaderboard is local only.

---

## Target topology

```
                  ┌──────────────────────────────────┐
                  │   BACK-OF-BOOTH MONITOR           │
                  │   DISPLAY client — kiosk mode     │  ← big attract-mode board,
                  │   fullscreen, auto-refresh        │     input-method badges,
                  └─────────────▲────────────────────┘     "NEW HIGH SCORE!" pops
                                │  live leaderboard updates (broadcast)
                  ┌─────────────┴────────────────────┐
                  │   LEADERBOARD SERVER (headless)   │  ← authoritative store,
                  │   runs on the back machine        │     persists + daily rollover
                  └───────▲──────────────────▲────────┘     + UDP discovery beacon
                  submit  │                  │  submit
        ┌─────────────────┴───┐    ┌─────────┴─────────────────┐
        │  STATION 1 (game)   │    │  STATION 2 (game)         │
        └─────────────────────┘    └───────────────────────────┘
                  └──── private LAN: cheap switch / travel router ────┘
                            (no internet required)
```

**Server runs on the back machine** (same box as the display kiosk): it is the
machine players never touch and that stays powered all day. Total hardware:
**3 computers** (2 stations + 1 back machine) + one small switch/router.

---

## Three roles, one project

Same exported project, launched in different modes. Selection via CLI flag
(preferred for kiosk shortcuts) with an optional on-screen launcher fallback:

| Role | Launch | Responsibility |
|---|---|---|
| **Station** | `AccessibleArchery --station` (also the default) | The game. On bank, submit score to server; fall back to local file if offline. |
| **Server** | `AccessibleArchery --server --headless` | Authoritative leaderboard; persistence; daily rollover; UDP discovery beacon; broadcast updates. No window. |
| **Display** | `AccessibleArchery --display` | Fullscreen attract-mode leaderboard kiosk. Read-only client. |

Read `OS.get_cmdline_args()` in an early autoload (or a `boot.gd` main scene that
routes to the right scene). Keep `main.tscn` as the Station scene; add
`server.tscn` and `display.tscn`.

Deployment: **no export** — the `booth/` double-click scripts run the project
directly through the Godot editor executable (`godot4 --path <project> --
<flags>`), so there's nothing to build or sign. Copy Godot + the project
folder together via USB; same source runs all three roles depending only on
which script is double-clicked. See `booth/README.md` and
`docs/BOOTH_RUNBOOK.md`.

---

## Networking

**Transport: Godot high-level multiplayer over ENet, dedicated-server model.**
Chosen for being idiomatic Godot, reusing the existing data model, and keeping
everything in one engine (display is a Godot kiosk, not a web page).

- Server: `ENetMultiplayerPeer.create_server(PORT, max_peers)`.
- Stations + display: `ENetMultiplayerPeer.create_client(server_ip, PORT)`.
- Stations → server: `submit_score.rpc_id(1, name, score, input_scheme)`.
- Server validates, updates store, persists, then
  `leaderboard_updated.rpc(payload)` to all peers.
- Display (and optionally stations) render on `leaderboard_updated`.

RPC sketch:

```gdscript
# On server
@rpc("any_peer", "reliable")
func submit_score(name: String, score: int, input_scheme: int) -> void:
    name = _sanitize(name)                 # profanity filter + length clamp
    if score < 0 or score > MAX_PLAUSIBLE: return   # sanity clamp
    _store.add(name, score, input_scheme)  # persists + daily bucket
    _broadcast()

func _broadcast() -> void:
    leaderboard_updated.rpc(_store.snapshot())

# On clients
@rpc("authority", "reliable")
func leaderboard_updated(snapshot: Array) -> void:
    # display renders; station may show global board
```

### Zero-config auto-discovery (booth magic)

Server broadcasts a UDP beacon (`PacketPeerUDP`, broadcast address) ~1×/sec:
`{"service":"accessible-archery-leaderboard","port":PORT,"name":"Booth"}`.
Stations/display listen on that UDP port, learn the server IP, and auto-connect.
**No IP typing; power-on order doesn't matter; a rebooted machine rejoins itself.**
Manual IP override available as a fallback in a config file / launcher.

*(Alternative considered: WebSocket, so the display could be any browser/tablet/
smart-TV. Rejected for v1 to avoid a second tech stack — revisit if a browser
display is ever wanted.)*

---

## Data model

Each score entry:

```gdscript
{
  "name": String,        # sanitized, <= 16 chars
  "score": int,
  "input": int,          # AssistSettings.InputScheme value
  "ts": int,             # unix time (for daily bucketing / tie-break)
  "station": String,     # optional, which station (analytics)
}
```

`input` drives the **input-method badge** on the display (see below). It comes
straight from `AssistSettings.input_scheme` at bank time — pass it through
`_do_bank()` → `submit_score`.

### Leaderboard scoping for a multi-day con

Server keeps **two buckets**, both persisted:

- **Today's Top 10** — resets each morning (staff action or automatic at a
  configured hour). Keeps the board fresh so more visitors land on it.
- **All-Time / Best of Show** — persists across the whole event.

Display can rotate between "TODAY" and "BEST OF SHOW" panels. Rollover archives
the day's board to a dated file before clearing today's bucket.

---

## Display kiosk (the back monitor) — attract mode

This is the storefront; make it lively:

- Large, high-contrast, readable from across an aisle.
- **Input-method badges** per row — the mission statement:
  ```
  1.  MAYA   280   🎙 Voice
  2.  JJ     265   🕹 Switch
  3.  SAM     240   👁 Eye-tracking
  4.  ALEX    235   ⌨ Keyboard
  ```
- **"🎉 NEW HIGH SCORE!"** animation when a station banks a top entry.
- Rotate TODAY ↔ BEST OF SHOW; maybe a short "how to play / accessibility" slide.
- Fullscreen, input-locked (can't be alt-tabbed/closed by a passerby).
- Reuse `ScoreboardWindow` / `ScoreboardPanel` layout code as the starting point.

---

## Resilience (must-have for a live booth)

- **Offline outbox:** if the server is unreachable, the station queues banked
  scores locally and flushes on reconnect — a player never loses a score.
- **Local fallback board:** each station keeps writing its own
  `user://leaderboard.json` so a lone machine still works if the network dies.
- **Auto-reconnect:** display/stations show "Connecting…" and rejoin
  automatically; no staff intervention.
- **Server persistence:** save on every change; reload on restart; **daily disk
  backup** (a con is long — don't lose Day 2).
- **Server = single source of truth.**

## Abuse / public-screen safety

- **Profanity filter** + length clamp on names (they go on a public monitor).
- **Max-plausible-score** clamp on the server (reject impossible submissions).
- Supervised booth = low cheat risk, so keep validation light but present.

---

## Mapping onto current code (refactor plan)

- Split `Leaderboard` (`scripts/leaderboard/leaderboard_store.gd`) into:
  - a **store** (data + disk persistence + daily buckets) — mostly what exists,
  - a **transport** layer: `standalone` (local file, today's behaviour) vs
    `client` (submit to server) vs `server` (authoritative). A `mode` selects it.
  The public API (`add_score`, `top`, `updated`) stays the same so `main.gd`
  and the scoreboards don't care whether they're networked.
- `_do_bank()` in `main.gd`: pass `AssistSettings.input_scheme` through to the
  score so the badge works.
- `ScoreboardWindow` / `ScoreboardPanel` content → basis for `display.tscn`.
- New: `scripts/net/leaderboard_server.gd`, `scripts/net/leaderboard_client.gd`,
  `scripts/net/discovery.gd` (UDP beacon), `server.tscn`, `display.tscn`,
  `scripts/boot.gd` (role routing from cmdline).

---

## Build order (milestones, each independently testable)

1. **Server + score submission.** ENet server holds the board; stations submit;
   server persists + broadcasts. Test with several instances on one machine.
2. **Display kiosk scene** with attract mode + input-method badges.
3. **UDP auto-discovery.** Remove manual IP config.
4. **Offline outbox + auto-reconnect.** Booth-hardening.
5. **Daily rollover + backups + profanity/score clamps.**
6. **Boot/role launcher + fullscreen/kiosk flags + one-page staff runbook.**

**Testing without hardware:** run one `--server --headless`, one `--display`, and
two default `--station` instances on a single dev machine, all pointing at
`127.0.0.1`. This validates the whole flow before three PCs are ever in a room.

---

## Hardware & booth setup (rough)

- 2 station PCs, 1 back PC (runs server headless + display kiosk), 1 large
  monitor for the back PC.
- 1 cheap gigabit switch **or** a travel router (e.g. GL.iNet) to make the
  private LAN. No internet needed.
- Wired ethernet preferred over WiFi for reliability.
- Per-station accessible input hardware as available (switch, adaptive
  controller, eye tracker, mic for voice — see `docs/VOICE.md`).

## Staff runbook (to be written alongside implementation)

One page: power-on order (any), how to confirm all three connected, how to
"reset today's board" each morning, where backups land, what to do if a station
shows "offline" (it keeps working; scores sync when the network returns).

---

## Open decisions to confirm before/while building

1. ~~**Score buckets:**~~ Decided: Today+All-Time, both capped at top 10.
   See `leaderboard_store.gd` (`entries` / `all_time_entries`).
2. ~~**Rollover:**~~ Decided: automatic, at `ROLLOVER_HOUR` (default 6am
   local) in `leaderboard_store.gd`. No staff button exists yet — add one if
   a con needs a manual reset mid-day.
3. ~~**Display rotation:**~~ Decided: TODAY ↔ BEST OF SHOW ↔ how-to-play,
   12s each. See `display_kiosk.gd`.
4. ~~**Launcher:**~~ Decided: pure CLI flags (`--station` / `--server
   --headless` / `--display`, plus `--kiosk` / `--windowed` /
   `--ip=<addr>`), wrapped in double-click scripts per machine — see
   `booth/`. No on-screen role picker; not needed once shortcuts are set up,
   and it would add a GUI surface with nothing to validate against real
   hardware. Revisit if staff ever need to switch a machine's role without
   re-clicking a different shortcut.
5. **Name policy:** free text + profanity filter (current lean, implemented
   in `leaderboard_net.gd`), or curated word-pick to avoid moderation
   entirely? Still open — the current blocklist is a small placeholder, not
   a real moderation system.

## Pointers for a fresh session

- Read `CLAUDE.md`, this file, then `scripts/main.gd` and
  `scripts/leaderboard/leaderboard_store.gd`.
- Godot 4.7 standard build. Run a station:
  `Godot --path . `  (main scene is the game). Reimport after adding
  `class_name` scripts. Autoload order is set in `project.godot`.
- Keep the "input never changes gameplay" invariant intact.
