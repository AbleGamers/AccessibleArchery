extends CanvasLayer
class_name SecondChannelHUD
## The VISUAL half of the GDD's "Second Channel": every audio/haptic cue is
## mirrored on-screen with clean, high-contrast graphics so Deaf and
## hard-of-hearing players get full parity.
##
##   * Wind indicator — direction arrow + km/h, always visible (mirrors the
##     audio wind shift and the haptic wind rumble).
##   * Captions — commentary/callouts (draw, loose, scores, wind shifts).
##   * Draw-snap flash — a brief screen pulse the instant full draw is reached
##     (mirrors the audio "full draw" and the haptic snap).
##   * Spoken announcements — the same caption text is spoken aloud through the
##     OS text-to-speech voice (AssistSettings.tts_enabled), so blind players
##     get everything Deaf players get: true Second Channel symmetry.

var _wind_label: Label
var _caption: Label
var _flash: ColorRect
var _caption_timer: float = 0.0
var _flash_t: float = 0.0
var _tts_voice: String = ""

func _ready() -> void:
	layer = 10
	# Discoverable by UI overlays (e.g. the character select announces the
	# highlighted athlete here) without wiring through main.
	add_to_group("second_channel")
	# Pick an OS English voice once; empty (e.g. headless) disables speech.
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		var all_voices := DisplayServer.tts_get_voices()
		if not all_voices.is_empty():
			_tts_voice = all_voices[0].get("id", "")
	else:
		_tts_voice = voices[0]

	# Full-screen white flash for the draw-snap (starts invisible).
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# Wind indicator, top-centre, high contrast.
	var wind_panel := PanelContainer.new()
	wind_panel.add_theme_stylebox_override("panel", _panel_style())
	wind_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wind_panel.position = Vector2(-110, 14)
	add_child(wind_panel)
	_wind_label = _make_label(26)
	_wind_label.custom_minimum_size = Vector2(220, 0)
	_wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wind_panel.add_child(_wind_label)

	# Caption bar, bottom-centre.
	var cap_panel := PanelContainer.new()
	cap_panel.add_theme_stylebox_override("panel", _panel_style())
	cap_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cap_panel.position = Vector2(-300, -90)
	cap_panel.custom_minimum_size = Vector2(600, 0)
	add_child(cap_panel)
	_caption = _make_label(30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.custom_minimum_size = Vector2(600, 0)
	cap_panel.add_child(_caption)

func _process(delta: float) -> void:
	# Poll wind each frame so the arrow tracks smoothly.
	_update_wind(Wind.lateral(), Wind.speed_kmh())

	if _caption_timer > 0.0:
		_caption_timer -= delta
		if _caption_timer <= 0.0:
			_caption.text = ""

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.color.a = clampf(_flash_t / 0.25, 0.0, 1.0) * 0.5

## Show a caption for a few seconds (commentary / callouts) and, unless the
## caller marks it transient (speak = false, for chatter that already has a
## dedicated sound), speak it aloud. New announcements interrupt stale speech
## so the voice never lags the game.
func announce(text: String, speak: bool = true) -> void:
	if AssistSettings.captions_enabled:
		_caption.text = text
		_caption_timer = 2.5
	if speak and AssistSettings.tts_enabled and _tts_voice != "":
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, _tts_voice, int(clampf(AssistSettings.tts_volume, 0.0, 100.0)))

## Flash the screen the moment full draw is reached.
func flash_draw_snap() -> void:
	_flash_t = 0.25

func _update_wind(lateral: float, kmh: float) -> void:
	var arrow := "•"
	if kmh >= 1.0:
		if lateral < -0.33:
			arrow = "◀◀" if lateral < -0.66 else "◀"
		elif lateral > 0.33:
			arrow = "▶▶" if lateral > 0.66 else "▶"
		else:
			arrow = "▲"   # roughly head-on / calm direction
	_wind_label.text = "WIND  %s  %d km/h" % [arrow, int(round(kmh))]

func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb
