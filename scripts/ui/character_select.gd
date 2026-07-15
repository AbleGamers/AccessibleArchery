extends CanvasLayer
class_name CharacterSelect
## Athlete select screen (GDD roster: four athletes, wheelchair users
## first-class). Four cards with live rotating 3D previews.
##
## Accessibility is structural: the screen listens to the SAME abstract intents
## as gameplay (InputRouter.captured_by_ui), so every device browses it the way
## it plays —
##   * rate devices (keys / stick / voice-nudges): left-right moves the highlight
##   * absolute devices (eye tracking, switch scan sweep): the aim's x position
##     IS the highlight
##   * ANY draw intent confirms (switch tap, dwell, "draw", key, button)
##   * with no input at all, the highlight auto-scans so a single switch can
##     simply wait and tap
##   * a pointer works too: hover highlights, click confirms
## Every selection is announced for captions/screen-reader-style feedback.
##
## Blind-station experience: opening the screen SPEAKS what it is, who is
## highlighted and how to browse/pick; every highlight move plays a PANNED tick
## (the blip sits where the card sits, pitch rises left→right) plus the spoken
## name; confirming plays a rising figure and speaks the pick. The gameplay
## targeting ping is silent while the menu is up (captured_by_ui), so the
## select screen owns the soundstage.

signal chosen(index: int)

const SCAN_SECONDS := 1.8       # auto-scan cadence when the player gives no input
const NAV_COOLDOWN := 0.35      # rate-device step repeat guard

var _root: Control
var _cards: Array[PanelContainer] = []
var _spinners: Array[Node3D] = []
var _selected: int = 0
var _open: bool = false
var _axis_x: float = 0.0
var _nav_cd: float = 0.0
var _scan_t: float = 0.0
var _idle_t: float = 99.0       # seconds since last manual input (gates auto-scan)

func _ready() -> void:
	layer = 25
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
	_set_selected(clampi(AssistSettings.athlete_index, 0, _cards.size() - 1), false)
	# Blind-station onboarding: one spoken line covers what the screen is, who
	# is highlighted, and how to browse and pick without sight. Single call so
	# the TTS isn't interrupted mid-sentence by a follow-up announcement.
	var def := AthleteRoster.get_def(_selected)
	_announce("Choose your athlete. %s, %d of %d, %s. Steer or wait to browse — draw to pick." % [def["name"], _selected + 1, _cards.size(), _spoken_tagline(def)])

func _confirm() -> void:
	_open = false
	InputRouter.captured_by_ui = false
	_root.visible = false
	AssistSettings.athlete_index = _selected
	AssistSettings.changed.emit()
	var audio := get_tree().get_first_node_in_group("audio_cues")
	if audio != null:
		audio.ui_confirm()
	_announce("%s selected — draw when ready." % AthleteRoster.get_def(_selected)["name"])
	chosen.emit(_selected)

# --- intent handling ------------------------------------------------------------

func _on_aim_axis(axis: Vector2) -> void:
	if _open:
		_axis_x = axis.x

func _on_aim_absolute(position: Vector2) -> void:
	if not _open:
		return
	# Map the aim's x straight onto the four columns; an eye tracker points at
	# a card, a switch scan sweeps the highlight back and forth on its own.
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
	for spinner in _spinners:
		spinner.rotation.y += delta * 0.7
	_nav_cd = maxf(_nav_cd - delta, 0.0)
	_idle_t += delta
	if absf(_axis_x) > 0.5 and _nav_cd <= 0.0:
		_set_selected(wrapi(_selected + (1 if _axis_x > 0.0 else -1), 0, _cards.size()))
		_nav_cd = NAV_COOLDOWN
		_idle_t = 0.0
	# Auto-scan for single-input players: if nothing has steered the highlight
	# for a while, it advances by itself — wait for your athlete, then tap.
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
	# blind player hears WHERE the highlight is, not just that it moved.
	var audio := get_tree().get_first_node_in_group("audio_cues")
	if audio != null:
		var f := float(index) / maxf(_cards.size() - 1, 1.0)
		audio.ui_tick(lerpf(-0.8, 0.8, f), f)
	if announce:
		var def := AthleteRoster.get_def(index)
		_announce("%s, %d of %d — %s" % [def["name"], index + 1, _cards.size(), _spoken_tagline(def)])

func _announce(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("second_channel")
	if hud != null:
		hud.announce(text)

# The on-card tagline uses a decorative separator ("Standing · Recurve"); give
# the TTS voice a plain comma so it reads naturally.
func _spoken_tagline(def: Dictionary) -> String:
	return str(def["tagline"]).replace(" · ", ", ")

# --- construction ---------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.09, 0.9)
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
	title.text = "CHOOSE YOUR ATHLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	for i in AthleteRoster.ATHLETES.size():
		row.add_child(_build_card(i))

	var hint := Label.new()
	hint.text = "Steer or look left/right to browse — or just wait, the highlight moves on its own.\nDraw (Space · A · switch tap · dwell · say \"draw\" · click) picks. Change any time with P."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	vb.add_child(hint)

func _build_card(index: int) -> PanelContainer:
	var def := AthleteRoster.get_def(index)
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
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	# Live rotating 3D preview in its own isolated world.
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(190, 230)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	var stage := Node3D.new()
	sv.add_child(stage)
	var model := Node3D.new()
	stage.add_child(model)
	AthleteRoster.build_body(model, def)
	var arms := Node3D.new()
	model.add_child(arms)
	AthleteRoster.build_arms(arms, def)
	_spinners.append(model)

	var cam := Camera3D.new()
	var mid := -0.55 if not def.get("seated", false) else -0.35
	cam.position = Vector3(0.0, mid + 0.15, -3.0)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, mid, 0.0), Vector3.UP)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35.0, 160.0, 0.0)
	stage.add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_energy = 0.5
	stage.add_child(fill)

	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(name_label)

	var tag := Label.new()
	tag.text = def["tagline"]
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
