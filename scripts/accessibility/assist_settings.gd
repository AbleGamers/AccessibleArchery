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

## When true there is never any time pressure (the draw holds indefinitely).
var unlimited_time: bool = true

## When true, aim direction and draw strength are sonified so the game is
## playable without sight. (See AudioCueSystem.)
var audio_cues_enabled: bool = true

## --- "Second Channel" redundancy (GDD: win by sight, sound, OR touch) --------
## Every critical cue — aim, wind, draw-tension — is broadcast on all three
## channels at once, so no single sense is required.

## High-contrast captions mirror commentary/callouts and audio events for Deaf
## and hard-of-hearing players.
var captions_enabled: bool = true

## Controller rumble guides aim (off-centre nudges) and conveys wind for blind /
## low-vision players. No effect without a connected gamepad.
var haptics_enabled: bool = true

## Dynamic wind nudges the arrow in flight; surfaced on all three channels.
var wind_enabled: bool = true

## Scales wind strength. Lower = gentler, an accessibility aid. 0 disables drift
## while still letting the cues teach the mechanic.
var wind_scale: float = 1.0

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

## Seconds of holding "draw" needed to reach full power. Larger values are
## friendlier to players with slow or imprecise input, and also set the
## auto-release timing for hands-free schemes (switch / eye tracking).
var full_draw_seconds: float = 1.2

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
	captions_enabled = data.get("captions_enabled", captions_enabled)
	haptics_enabled = data.get("haptics_enabled", haptics_enabled)
	wind_enabled = data.get("wind_enabled", wind_enabled)
	wind_scale = data.get("wind_scale", wind_scale)
	camera_on_left = data.get("camera_on_left", camera_on_left)
	full_draw_seconds = data.get("full_draw_seconds", full_draw_seconds)
	input_scheme = int(data.get("input_scheme", input_scheme))
	player_name = str(data.get("player_name", player_name))

func _save() -> void:
	var data := {
		"aim_sensitivity": aim_sensitivity,
		"aim_assist": aim_assist,
		"target_size_scale": target_size_scale,
		"audio_cues_enabled": audio_cues_enabled,
		"captions_enabled": captions_enabled,
		"haptics_enabled": haptics_enabled,
		"wind_enabled": wind_enabled,
		"wind_scale": wind_scale,
		"camera_on_left": camera_on_left,
		"full_draw_seconds": full_draw_seconds,
		"input_scheme": int(input_scheme),
		"player_name": player_name,
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
	return "Unknown"

func controls_hint() -> String:
	match input_scheme:
		InputScheme.KEYBOARD_MOUSE:
			return "Aim: arrows / WASD   Draw: hold Space   Fire: release"
		InputScheme.GAMEPAD:
			return "Aim: left stick   Draw: hold A   Fire: release"
		InputScheme.SINGLE_SWITCH:
			return "Switch (Space/A): tap to lock horizontal, tap to lock vertical, then auto-fire"
		InputScheme.EYE_TRACKING:
			return "Aim: gaze (mouse stand-in)   Draw: dwell / hold gaze   Fire: auto at full draw"
		InputScheme.VOICE:
			return "Say / debug keys: arrows=aim  Q=draw  E=loose  C=center"
	return ""
