extends CanvasLayer
class_name PlaystyleSelect
## The "How do you want to play?" screen (GDD: accessibility presets, audio-first
## entry). Shown once on first launch — BEFORE athlete select — so a new player
## sets up the experience, and a blind player discovers audio-guided play by ear
## the moment the game speaks. Skipped on later launches (AssistSettings.
## setup_complete); reopened from the options menu or when setup is re-run.
##
## Discoverability is the whole point: the same abstract intents drive it as
## gameplay (InputRouter.captured_by_ui), so every device browses it the way it
## plays, and it SPEAKS itself on open — the audible half of the "how do I even
## turn this on?" problem. It deliberately reuses the athlete-select pattern:
##   * rate devices (keys / stick / voice-nudges): left-right moves the highlight
##   * absolute devices (eye tracking, switch scan): the aim's x IS the highlight
##   * ANY draw intent confirms; with no input the highlight auto-scans so a
##     single switch can just wait and tap; a pointer hovers + clicks
## Every move plays a panned tick and speaks the preset; confirming applies the
## whole PlayPresets bundle at once.

signal chosen(index: int)

const SCAN_SECONDS := 2.2       # auto-scan cadence when the player gives no input
const NAV_COOLDOWN := 0.35      # rate-device step repeat guard

var _root: Control
var _cards: Array[PanelContainer] = []
var _selected: int = 0
var _open: bool = false
var _axis_x: float = 0.0
var _nav_cd: float = 0.0
var _scan_t: float = 0.0
var _idle_t: float = 99.0       # seconds since last manual input (gates auto-scan)

func _ready() -> void:
	layer = 26                  # above athlete select (25), below the options menu (20 dims below it)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	InputRouter.aim_axis.connect(_on_aim_axis)
	InputRouter.aim_absolute.connect(_on_aim_absolute)
	InputRouter.draw_pressed.connect(_on_draw_pressed)

func is_open() -> bool:
	return _open

func open() -> void:
	_open = true
	InputRouter.captured_by_ui = true
	_root.visible = true
	_idle_t = 99.0
	_scan_t = 0.0
	_set_selected(clampi(AssistSettings.playstyle_index, 0, _cards.size() - 1), false)
	# Audio-first onboarding: one spoken line names the game, what this screen is,
	# which mode is highlighted, and how to browse and pick — so a blind player is
	# oriented before touching a single visual-only control. Single call so the
	# TTS isn't cut off mid-sentence by a follow-up announcement.
	var def := PlayPresets.get_def(_selected)
	_announce("Accessible Archery. How do you want to play? %s. %s Steer or wait to browse — draw to pick. Press Escape any time for detailed options." % [def["name"], def["spoken"]])

func _confirm() -> void:
	_open = false
	InputRouter.captured_by_ui = false
	_root.visible = false
	PlayPresets.apply(_selected)
	var audio := get_tree().get_first_node_in_group("audio_cues")
	if audio != null:
		audio.ui_confirm()
	_announce("%s selected." % PlayPresets.get_def(_selected)["name"])
	chosen.emit(_selected)

# --- intent handling ------------------------------------------------------------

func _on_aim_axis(axis: Vector2) -> void:
	if _open:
		_axis_x = axis.x

func _on_aim_absolute(position: Vector2) -> void:
	if not _open:
		return
	var col := clampi(int((position.x + 1.0) * 0.5 * _cards.size()), 0, _cards.size() - 1)
	if col != _selected:
		_set_selected(col)
	_idle_t = 0.0

func _on_draw_pressed() -> void:
	if _open:
		_confirm()

func _process(delta: float) -> void:
	if not _open:
		return
	_nav_cd = maxf(_nav_cd - delta, 0.0)
	_idle_t += delta
	if absf(_axis_x) > 0.5 and _nav_cd <= 0.0:
		_set_selected(wrapi(_selected + (1 if _axis_x > 0.0 else -1), 0, _cards.size()))
		_nav_cd = NAV_COOLDOWN
		_idle_t = 0.0
	# Auto-scan for single-input players: with no steering for a few seconds the
	# highlight advances on its own — wait for your mode, then tap.
	if _idle_t > 3.0:
		_scan_t += delta
		if _scan_t >= SCAN_SECONDS:
			_scan_t = 0.0
			_set_selected(wrapi(_selected + 1, 0, _cards.size()))
	else:
		_scan_t = 0.0

func _set_selected(index: int, announce: bool = true) -> void:
	_selected = index
	for i in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _card_style(i == _selected))
	# Panned tick: the blip sits where the card sits in the stereo field, so a
	# blind player hears WHICH mode is highlighted, not just that it moved.
	var audio := get_tree().get_first_node_in_group("audio_cues")
	if audio != null:
		var f := float(index) / maxf(_cards.size() - 1, 1.0)
		audio.ui_tick(lerpf(-0.8, 0.8, f), f)
	if announce:
		var def := PlayPresets.get_def(index)
		_announce("%s. %s" % [def["name"], def["spoken"]])

func _announce(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("second_channel")
	if hud != null:
		hud.announce(text)

# --- construction ---------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.09, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var title := Label.new()
	title.text = "HOW DO YOU WANT TO PLAY?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "You can change this any time — nothing here is locked in."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	vb.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	for i in PlayPresets.count():
		row.add_child(_build_card(i))

	var hint := Label.new()
	hint.text = "Steer or look left/right to browse — or just wait, the highlight moves on its own.\nDraw (Space · A · switch tap · dwell · say \"draw\" · click) picks.  Esc: detailed options."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	vb.add_child(hint)

func _build_card(index: int) -> PanelContainer:
	var def := PlayPresets.get_def(index)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(false))
	_cards.append(card)

	# Pointer path: hover highlights, click confirms.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		if _open and index != _selected:
			_set_selected(index)
			_idle_t = 0.0)
	card.gui_input.connect(func(event: InputEvent):
		if _open and event is InputEventMouseButton and event.pressed:
			_set_selected(index)
			_confirm())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(210, 240)
	card.add_child(vb)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer_top)

	var icon := Label.new()
	icon.text = def["icon"]
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 76)
	vb.add_child(icon)

	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(name_label)

	var tag := Label.new()
	tag.text = def["tagline"]
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	vb.add_child(tag)
	return card

func _card_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.18, 0.98) if not selected else Color(0.14, 0.19, 0.27, 1.0)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.95, 0.85, 0.35) if selected else Color(0.25, 0.30, 0.38)
	return sb
