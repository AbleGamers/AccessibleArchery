extends Node
## Central, player-controlled accessibility & assist configuration.
##
## Every gameplay system reads from here, so accessibility is a first-class
## concern rather than magic numbers scattered across the codebase. A settings
## UI (future work) only needs to write to this autoload.
##
## Autoloaded as `AssistSettings`.

signal changed

enum InputScheme {
	KEYBOARD_MOUSE,
	GAMEPAD,
	SINGLE_SWITCH,
	EYE_TRACKING,
	VOICE,
	BRIDGE,   # any external assistive interface via the UDP AT Bridge protocol
}

## Which input scheme is currently driving the game. Swapping this is how a
## player selects the device that works for them.
var input_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE

## Multiplies steering speed for rate-based devices. Lower = slower, steadier
## aim — an accessibility aid for tremor or limited range of motion.
var aim_sensitivity: float = 1.0

## 0.0 = no aim assist, 1.0 = arrow strongly magnetised toward the target.
var aim_assist: float = 0.0

## Scales every target. > 1.0 makes targets bigger / easier to hit.
var target_size_scale: float = 1.0

## When true there is never any time pressure: breath never runs out, so the
## draw can be held steady indefinitely. An accessibility escape hatch from the
## over-hold mechanic (see sway_scale / breath_seconds).
var unlimited_time: bool = false

## Scales reticle sway (the GDD's draw-tension wobble). 1.0 = standard,
## 0.0 = perfectly steady aim — the accessibility floor. Also scales how fast
## the over-hold penalty grows.
var sway_scale: float = 1.0

## Auto-engage the held breath the instant the draw reaches full tension — no
## extra button (the deck's "auto-hold breath"). Off = breath is held manually
## via the `steady` intent (devices without one keep auto behaviour).
var auto_hold_breath: bool = true

## How long held breath keeps the aim steady at full draw before it runs out
## and sway spikes. Larger = a wider release window (an accessibility aid).
var breath_seconds: float = 2.5

## Tap-to-draw instead of hold-to-draw for hold-based devices (keyboard,
## gamepad): one press starts the draw, the next press looses. Removes
## sustained muscle strain (the deck's "same control, different").
var toggle_draw: bool = false

## When true, aim direction and draw strength are sonified so the game is
## playable without sight. (See AudioCueSystem.)
var audio_cues_enabled: bool = true

## Procedural sound effects & crowd (SfxSystem) — atmosphere, not information:
## everything it reacts to is also captioned. Separate from audio_cues_enabled
## so a blind player can keep the cues and drop the noise, or vice versa.
var sfx_enabled: bool = true

## Level for the accessibility tones (AudioCueSystem): ping, draw tone, chirp,
## breath metronome, UI ticks. 1.0 = default mix, up to 1.5 for a loud venue —
## independent of sfx_volume so a booth can run the cues hot and the crowd
## quiet on the same machine, without touching OS volume.
var cue_volume: float = 1.0

## Level for atmosphere/feedback (SfxSystem): crowd, whoosh, thunk, fanfare.
var sfx_volume: float = 1.0

## Level for the OS text-to-speech voice, 0-100 (percentage, per
## DisplayServer.tts_speak). Independent of tts_enabled so a station can keep
## speech on but duck it under the tones, or vice versa.
var tts_volume: float = 100.0

## --- Sound-cue tuning (the AudioCueSystem knobs, player-adjustable) -----------
## Every value that shapes how the aiming tones FEEL lives here, not as a magic
## number in the synth, so a player can dial the guidance to their own ears from
## the options menu (hearing range, tempo tolerance, how much help they want).

## Pitch range of the aiming tones (Hz): the ping's low end (far from centre)
## and high end (dead centre), and the reference/spread for the draw tone. Raise
## the low end or lower the high end for high-frequency hearing loss or
## hyperacusis.
var cue_pitch_low: float = 220.0
var cue_pitch_high: float = 880.0

## Multiplies the ping cadence — higher = the beeps come faster at every
## distance. A tempo preference / processing-speed aid.
var cue_tempo: float = 1.0

## The guidance cone, in degrees: how far off a target the aim can be before the
## cues (and the precision-aim slowdown) start reacting. Wider = help kicks in
## from further out; narrower = the cues only tighten when you are already close.
## Shared by the audio ping, the haptics, and the precision-aim zone so "how
## early does the game start guiding me" is one honest number.
var guidance_cone_deg: float = 12.0

## How sharply the stereo pan swings toward the target side. Higher = the ping
## jumps hard left/right for a small aim error (easier to hear direction, harder
## to hold centred).
var pan_strength: float = 4.0

## The separate-in-time elevation cue: when your aim is off vertically, an
## alternating centred beat says up (rising pair) or down (falling pair). Turn
## it off to steer on the left/right ping alone (some players find the extra
## beat noisy and prefer the spoken high/low callout after each shot).
var elevation_cue_enabled: bool = true

## How dramatic the up/down pitch jump is (octaves at full error). Bigger = a
## more obvious rise/fall for the same elevation error.
var elevation_interval: float = 0.75

## How loud the aiming ping stays UNDER the draw tone while you hold a draw
## (0 = silent, like the old behaviour; 1 = as loud as when not drawing). Raise
## it if the draw tone masks your ability to hear drift off the gold.
var aim_cue_while_drawing: float = 0.5

## Volume of the steady-breath metronome ticks (0 = off). The countdown of the
## release window; some players want it prominent, others find it distracting.
var breath_tick_volume: float = 1.0

## --- "Second Channel" redundancy (GDD: win by sight, sound, OR touch) --------
## Every critical cue — aim, wind, draw-tension — is broadcast on all three
## channels at once, so no single sense is required.

## High-contrast captions mirror commentary/callouts and audio events for Deaf
## and hard-of-hearing players.
var captions_enabled: bool = true

## Speak the caption channel aloud through the OS text-to-speech voice — the
## audio mirror of captions, for blind / low-vision play (scores, match state,
## breath warnings, wind shifts, athlete selection).
var tts_enabled: bool = true

## Controller rumble guides aim (off-centre nudges) and conveys wind for blind /
## low-vision players. No effect without a connected gamepad.
var haptics_enabled: bool = true

## Dynamic wind nudges the arrow in flight; surfaced on all three channels.
var wind_enabled: bool = true

## Scales wind strength. Lower = gentler, an accessibility aid. 0 disables drift
## while still letting the cues teach the mechanic.
var wind_scale: float = 1.0

## Cinematic "target cam" after each shot (cut to the target, watch the arrow
## land, cut back). Off = the camera never leaves the player's shoulder — a
## reduce-motion / predictability option.
var impact_cam_enabled: bool = true

## Which side the over-the-shoulder camera sits on. Flips the whole rig so the
## archer can be framed on the left or the right — a comfort/accessibility option
## for handedness, eye dominance, or screen placement. true = camera on the
## archer's left (archer appears on the right of the screen).
var camera_on_left: bool = true

## Whether the separate scoreboard window is shown. Driven by both the B hotkey
## and the options menu; the main scene mirrors it onto the actual window.
var scoreboard_visible: bool = false

## The player's name, used when banking scores onto the leaderboard. Persisted.
var player_name: String = ""

## Which roster athlete is selected (index into AthleteRoster.ATHLETES).
## Purely presentational plus shooting height — never gameplay advantage.
var athlete_index: int = 0

## Which play-style preset is active (index into PlayPresets.PRESETS). Set by the
## "How do you want to play?" picker; drives which card it highlights next time.
var playstyle_index: int = 0

## True once the player has been through first-run setup (picked a play style).
## Gates the play-style picker: shown on first launch, skipped afterwards (the
## player can reopen it from the options menu). At a booth each station is
## configured once, then walk-up players go straight to athlete select.
var setup_complete: bool = false

## Player rebinds of input actions (action name -> serialized InputEvent).
## Written by the remapping UI via InputRouter.rebind(); applied on startup.
## Remapping is itself an accessibility feature: a lot of assistive hardware
## shows up as "a keyboard that only types one unusual key".
var input_overrides: Dictionary = {}

## Seconds of holding "draw" needed to reach full power. Larger values are
## friendlier to players with slow or imprecise input, and also set the
## auto-release timing for hands-free schemes (switch / eye tracking).
var full_draw_seconds: float = 1.2

## Rate steering slows as the aim closes on a target — a device-agnostic
## "precision zone": coarse sweeps stay fast, the last few degrees are fine.
## 0 = constant speed everywhere, 0.9 = crawl over the gold. Applies to every
## rate device identically, so no device gains an aim advantage.
var precision_slowdown: float = 0.65

# --- Persistence (user://) ----------------------------------------------------
# Accessibility choices are saved so a player only sets them up once. Writes are
# debounced so dragging a slider doesn't hammer the disk.

const SAVE_PATH := "user://settings.json"
var _save_timer: Timer

func _ready() -> void:
	_load()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	add_child(_save_timer)
	_save_timer.timeout.connect(_save)
	changed.connect(request_save)

## Queue a debounced save without broadcasting `changed` — for state (like the
## player name) that other systems don't need to react to live.
func request_save() -> void:
	if _save_timer != null:
		_save_timer.start()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	# Assign directly (no `changed` emit): dependents read these on their _ready.
	aim_sensitivity = data.get("aim_sensitivity", aim_sensitivity)
	aim_assist = data.get("aim_assist", aim_assist)
	target_size_scale = data.get("target_size_scale", target_size_scale)
	audio_cues_enabled = data.get("audio_cues_enabled", audio_cues_enabled)
	sfx_enabled = data.get("sfx_enabled", sfx_enabled)
	cue_volume = data.get("cue_volume", cue_volume)
	sfx_volume = data.get("sfx_volume", sfx_volume)
	tts_volume = data.get("tts_volume", tts_volume)
	cue_pitch_low = data.get("cue_pitch_low", cue_pitch_low)
	cue_pitch_high = data.get("cue_pitch_high", cue_pitch_high)
	cue_tempo = data.get("cue_tempo", cue_tempo)
	guidance_cone_deg = data.get("guidance_cone_deg", guidance_cone_deg)
	pan_strength = data.get("pan_strength", pan_strength)
	elevation_cue_enabled = data.get("elevation_cue_enabled", elevation_cue_enabled)
	elevation_interval = data.get("elevation_interval", elevation_interval)
	aim_cue_while_drawing = data.get("aim_cue_while_drawing", aim_cue_while_drawing)
	breath_tick_volume = data.get("breath_tick_volume", breath_tick_volume)
	captions_enabled = data.get("captions_enabled", captions_enabled)
	tts_enabled = data.get("tts_enabled", tts_enabled)
	haptics_enabled = data.get("haptics_enabled", haptics_enabled)
	wind_enabled = data.get("wind_enabled", wind_enabled)
	wind_scale = data.get("wind_scale", wind_scale)
	unlimited_time = data.get("unlimited_time", unlimited_time)
	sway_scale = data.get("sway_scale", sway_scale)
	auto_hold_breath = data.get("auto_hold_breath", auto_hold_breath)
	breath_seconds = data.get("breath_seconds", breath_seconds)
	toggle_draw = data.get("toggle_draw", toggle_draw)
	impact_cam_enabled = data.get("impact_cam_enabled", impact_cam_enabled)
	camera_on_left = data.get("camera_on_left", camera_on_left)
	full_draw_seconds = data.get("full_draw_seconds", full_draw_seconds)
	precision_slowdown = data.get("precision_slowdown", precision_slowdown)
	input_scheme = int(data.get("input_scheme", input_scheme))
	player_name = str(data.get("player_name", player_name))
	athlete_index = int(data.get("athlete_index", athlete_index))
	playstyle_index = int(data.get("playstyle_index", playstyle_index))
	setup_complete = bool(data.get("setup_complete", setup_complete))
	var overrides: Variant = data.get("input_overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY:
		input_overrides = overrides

func _save() -> void:
	var data := {
		"aim_sensitivity": aim_sensitivity,
		"aim_assist": aim_assist,
		"target_size_scale": target_size_scale,
		"audio_cues_enabled": audio_cues_enabled,
		"sfx_enabled": sfx_enabled,
		"cue_volume": cue_volume,
		"sfx_volume": sfx_volume,
		"tts_volume": tts_volume,
		"cue_pitch_low": cue_pitch_low,
		"cue_pitch_high": cue_pitch_high,
		"cue_tempo": cue_tempo,
		"guidance_cone_deg": guidance_cone_deg,
		"pan_strength": pan_strength,
		"elevation_cue_enabled": elevation_cue_enabled,
		"elevation_interval": elevation_interval,
		"aim_cue_while_drawing": aim_cue_while_drawing,
		"breath_tick_volume": breath_tick_volume,
		"captions_enabled": captions_enabled,
		"tts_enabled": tts_enabled,
		"haptics_enabled": haptics_enabled,
		"wind_enabled": wind_enabled,
		"wind_scale": wind_scale,
		"unlimited_time": unlimited_time,
		"sway_scale": sway_scale,
		"auto_hold_breath": auto_hold_breath,
		"breath_seconds": breath_seconds,
		"toggle_draw": toggle_draw,
		"impact_cam_enabled": impact_cam_enabled,
		"camera_on_left": camera_on_left,
		"full_draw_seconds": full_draw_seconds,
		"precision_slowdown": precision_slowdown,
		"input_scheme": int(input_scheme),
		"player_name": player_name,
		"athlete_index": athlete_index,
		"playstyle_index": playstyle_index,
		"setup_complete": setup_complete,
		"input_overrides": input_overrides,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))

func set_input_scheme(scheme: InputScheme) -> void:
	if scheme != input_scheme:
		input_scheme = scheme
		changed.emit()

func scheme_label() -> String:
	match input_scheme:
		InputScheme.KEYBOARD_MOUSE: return "Keyboard / Mouse"
		InputScheme.GAMEPAD: return "Gamepad"
		InputScheme.SINGLE_SWITCH: return "Single Switch"
		InputScheme.EYE_TRACKING: return "Eye Tracking"
		InputScheme.VOICE: return "Voice"
		InputScheme.BRIDGE: return "AT Bridge (UDP)"
	return "Unknown"

## Icon + short label for an arbitrary scheme (leaderboard entries store the
## scheme the score was banked under, which may differ from the current
## player's). -1 = unknown/legacy entry (pre-input-tagging score).
static func badge_for(scheme: int) -> String:
	match scheme:
		InputScheme.KEYBOARD_MOUSE: return "⌨ Keyboard"
		InputScheme.GAMEPAD: return "🎮 Gamepad"
		InputScheme.SINGLE_SWITCH: return "🕹 Switch"
		InputScheme.EYE_TRACKING: return "👁 Eye-tracking"
		InputScheme.VOICE: return "🎙 Voice"
		InputScheme.BRIDGE: return "🔌 Bridge"
	return "Unknown"

func controls_hint() -> String:
	match input_scheme:
		InputScheme.KEYBOARD_MOUSE:
			if toggle_draw:
				return "Aim: arrows / WASD   Draw: tap Space (tap again to fire)   Steady: hold Shift"
			return "Aim: arrows / WASD   Draw: hold Space   Steady: hold Shift   Fire: release"
		InputScheme.GAMEPAD:
			if toggle_draw:
				return "Aim: left stick   Draw: tap A (tap again to fire)   Steady: hold X"
			return "Aim: left stick   Draw: hold A   Steady: hold X   Fire: release"
		InputScheme.SINGLE_SWITCH:
			return "Switch (Space/A): tap to lock horizontal, tap to lock vertical, then auto-fire"
		InputScheme.EYE_TRACKING:
			return "Aim: gaze (mouse stand-in)   Draw: dwell / hold gaze   Fire: auto at full draw"
		InputScheme.VOICE:
			return "Say / debug keys: arrows=aim  Q=draw  E=loose  C=center"
		InputScheme.BRIDGE:
			return "External interface on UDP :9010 — see docs/AT_BRIDGE.md (try tools/at_bridge_demo.py)"
	return ""

## Which screen side the scoreboard overlays should sit on so they never cover
## the downrange targets. The over-the-shoulder rig frames the targets on the
## OPPOSITE side from the camera shoulder — camera on the right (camera_on_left
## = false) puts the targets on the right — so the boards ride the side the
## camera is on, and flip with it (V / the options menu). Verified in-game
## against both camera sides.
func scoreboard_on_left() -> bool:
	return not camera_on_left
