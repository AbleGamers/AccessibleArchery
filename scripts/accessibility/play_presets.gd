extends Object
class_name PlayPresets
## Named accessibility PRESETS — the "How do you want to play?" screen picks one
## and this applies a whole bundle of AssistSettings at once, so a player never
## has to assemble the right combination of a dozen toggles by hand (the GDD's
## discoverability fix: the headline "Audio-guided" mode is one tap, not a
## scavenger hunt through the options menu).
##
## A preset is orthogonal to the input DEVICE: "Audio-guided" plays by ear on a
## gamepad, keyboard, or voice alike. Only the "One switch" preset also pins the
## input scheme, because single-switch play is a device + assist bundle people
## reach for together. Each preset lists ONLY the keys it wants to set; anything
## absent (player name, camera side, etc.) is left exactly as the player had it.
##
## The `spoken` line is read aloud by the picker (TTS), so it is written to be
## heard, not skimmed — it says what the mode does, in plain words.

const PRESETS: Array[Dictionary] = [
	{
		"id": "standard",
		"name": "Standard",
		"icon": "🎯",
		"tagline": "Play by sight",
		"spoken": "Standard. Play by sight, with captions and rumble. Best on a gamepad or keyboard.",
		"settings": {
			"audio_cues_enabled": false,
			"tts_enabled": false,
			"sfx_enabled": true,
			"captions_enabled": true,
			"haptics_enabled": true,
			"aim_assist": 0.0,
			"aim_sensitivity": 1.0,
			"precision_slowdown": 0.65,
			"sway_scale": 1.0,
			"target_size_scale": 1.0,
			"unlimited_time": false,
			"wind_scale": 1.0,
			"impact_cam_enabled": true,
		},
	},
	{
		"id": "audio_guided",
		"name": "Audio-guided",
		"icon": "🎧",
		"tagline": "Play by ear · no screen needed",
		"spoken": "Audio guided. Play entirely by ear — the sound leads you to the target and speaks every score. Put headphones on. This is the blindfold mode.",
		"settings": {
			"audio_cues_enabled": true,
			"tts_enabled": true,
			"sfx_enabled": true,
			"captions_enabled": true,
			"haptics_enabled": true,
			"aim_assist": 0.25,
			"aim_sensitivity": 0.7,
			"precision_slowdown": 0.8,
			"sway_scale": 1.0,
			"target_size_scale": 1.0,
			"unlimited_time": false,
			"wind_scale": 0.5,
			"impact_cam_enabled": true,
		},
	},
	{
		"id": "calm",
		"name": "Low-motion & forgiving",
		"icon": "🌿",
		"tagline": "Big targets · steady aim · no timer",
		"spoken": "Low motion and forgiving. Big targets, steady aim, no time pressure, and the camera stays put. Good for low vision, tremor, or motion sensitivity.",
		"settings": {
			"audio_cues_enabled": true,
			"tts_enabled": true,
			"sfx_enabled": true,
			"captions_enabled": true,
			"haptics_enabled": true,
			"aim_assist": 0.4,
			"aim_sensitivity": 0.7,
			"precision_slowdown": 0.8,
			"sway_scale": 0.2,
			"target_size_scale": 1.6,
			"unlimited_time": true,
			"wind_scale": 0.0,
			"impact_cam_enabled": false,
		},
	},
	{
		"id": "one_switch",
		"name": "One switch",
		"icon": "🔘",
		"tagline": "One button does everything",
		"spoken": "One switch. A single button aims and shoots by itself — tap to lock left and right, tap to lock height, and it looses for you. No time pressure.",
		"settings": {
			"input_scheme": AssistSettings.InputScheme.SINGLE_SWITCH,
			"audio_cues_enabled": true,
			"tts_enabled": true,
			"sfx_enabled": true,
			"captions_enabled": true,
			"haptics_enabled": true,
			"aim_assist": 0.4,
			"aim_sensitivity": 1.0,
			"precision_slowdown": 0.65,
			"sway_scale": 0.3,
			"target_size_scale": 1.3,
			"unlimited_time": true,
			"wind_scale": 0.0,
			"impact_cam_enabled": true,
		},
	},
]

static func count() -> int:
	return PRESETS.size()

static func get_def(index: int) -> Dictionary:
	return PRESETS[clampi(index, 0, PRESETS.size() - 1)]

## Apply the preset's whole settings bundle to AssistSettings and broadcast it,
## so every system reconfigures live. Also records which preset is active and
## marks first-run setup complete (so the picker is skipped next launch).
static func apply(index: int) -> void:
	var def := get_def(index)
	var settings: Dictionary = def["settings"]
	for key in settings:
		AssistSettings.set(key, settings[key])
	AssistSettings.playstyle_index = clampi(index, 0, PRESETS.size() - 1)
	AssistSettings.setup_complete = true
	AssistSettings.changed.emit()
