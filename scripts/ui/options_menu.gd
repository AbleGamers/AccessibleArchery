extends CanvasLayer
class_name OptionsMenu
## In-game accessibility & options menu (Esc to open/close). Every control reads
## and writes AssistSettings and then emits AssistSettings.changed, so the rest
## of the game updates live and the hotkeys (which do the same thing) stay fully
## in sync. The menu is an overlay — it does not pause — so all hotkeys keep
## working while it is open.

var _root: Control
var _dim: ColorRect
var _syncing: bool = false
var _binders: Array[Callable] = []   # re-read each control from settings on open

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func is_open() -> bool:
	return _root.visible

func toggle() -> void:
	if _root.visible:
		close()
	else:
		open()

func open() -> void:
	_sync_all()
	_root.visible = true

func close() -> void:
	_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the menu (opening is handled by the main scene's hotkeys).
	if _root.visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

# --- build --------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks to the game
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	vb.add_child(_heading("Accessibility & Options"))
	vb.add_child(_hint("Every option here also has a hotkey. Esc closes this menu."))
	vb.add_child(HSeparator.new())

	_name_row(vb)
	vb.add_child(HSeparator.new())

	_toggle_row(vb, "Audio cues (sonified aim)",
		func(): return AssistSettings.audio_cues_enabled,
		func(v): AssistSettings.audio_cues_enabled = v)
	_toggle_row(vb, "Captions / callouts",
		func(): return AssistSettings.captions_enabled,
		func(v): AssistSettings.captions_enabled = v)
	_toggle_row(vb, "Haptic feedback (controller)",
		func(): return AssistSettings.haptics_enabled,
		func(v): AssistSettings.haptics_enabled = v)
	_toggle_row(vb, "Wind",
		func(): return AssistSettings.wind_enabled,
		func(v): AssistSettings.wind_enabled = v)
	_toggle_row(vb, "Camera on left  (hotkey: V)",
		func(): return AssistSettings.camera_on_left,
		func(v): AssistSettings.camera_on_left = v)
	_toggle_row(vb, "Show scoreboard window  (hotkey: B)",
		func(): return AssistSettings.scoreboard_visible,
		func(v): AssistSettings.scoreboard_visible = v)

	vb.add_child(HSeparator.new())

	_slider_row(vb, "Aim sensitivity", 0.3, 2.0, 0.1,
		func(): return AssistSettings.aim_sensitivity,
		func(v): AssistSettings.aim_sensitivity = v)
	_slider_row(vb, "Aim assist", 0.0, 1.0, 0.05,
		func(): return AssistSettings.aim_assist,
		func(v): AssistSettings.aim_assist = v)
	_slider_row(vb, "Target size", 0.5, 2.5, 0.1,
		func(): return AssistSettings.target_size_scale,
		func(v): AssistSettings.target_size_scale = v)
	_slider_row(vb, "Wind strength", 0.0, 1.5, 0.1,
		func(): return AssistSettings.wind_scale,
		func(v): AssistSettings.wind_scale = v)
	_slider_row(vb, "Draw time (seconds)", 0.4, 3.0, 0.1,
		func(): return AssistSettings.full_draw_seconds,
		func(v): AssistSettings.full_draw_seconds = v)

	vb.add_child(HSeparator.new())
	_scheme_row(vb)

	vb.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Close  (Esc)"
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)

# --- rows ---------------------------------------------------------------------

func _toggle_row(parent: VBoxContainer, label: String, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var l := _text(label)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var cb := CheckButton.new()
	cb.toggled.connect(func(v):
		if _syncing:
			return
		setter.call(v)
		AssistSettings.changed.emit())
	row.add_child(cb)
	parent.add_child(row)
	_binders.append(func(): cb.button_pressed = bool(getter.call()))

func _slider_row(parent: VBoxContainer, label: String, lo: float, hi: float, step: float, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _text(label)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 0)
	row.add_child(slider)
	var val := _text("")
	val.custom_minimum_size = Vector2(48, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	slider.value_changed.connect(func(v):
		val.text = "%.2f" % v
		if _syncing:
			return
		setter.call(v)
		AssistSettings.changed.emit())
	parent.add_child(row)
	_binders.append(func():
		slider.value = float(getter.call())
		val.text = "%.2f" % slider.value)

func _name_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _text("Player name")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var le := LineEdit.new()
	le.max_length = 16
	le.custom_minimum_size = Vector2(200, 0)
	le.add_theme_font_size_override("font_size", 18)
	# Save without broadcasting `changed` so typing doesn't rebuild the world.
	le.text_changed.connect(func(t):
		if _syncing:
			return
		AssistSettings.player_name = t
		AssistSettings.request_save())
	row.add_child(le)
	parent.add_child(row)
	_binders.append(func(): le.text = AssistSettings.player_name)

func _scheme_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var l := _text("Input device")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var opt := OptionButton.new()
	for scheme_name in ["Keyboard / Mouse", "Gamepad", "Single Switch", "Eye Tracking", "Voice"]:
		opt.add_item(scheme_name)
	opt.item_selected.connect(func(idx):
		if _syncing:
			return
		AssistSettings.set_input_scheme(idx))
	row.add_child(opt)
	parent.add_child(row)
	_binders.append(func(): opt.select(int(AssistSettings.input_scheme)))

func _sync_all() -> void:
	_syncing = true
	for b in _binders:
		b.call()
	_syncing = false

# --- little widgets -----------------------------------------------------------

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	return l

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	return l

func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color.WHITE)
	return l
