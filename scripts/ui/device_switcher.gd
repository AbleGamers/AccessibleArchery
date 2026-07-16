extends CanvasLayer
class_name DeviceSwitcher
## Playtest-only device switcher. Players pick their device up front in the
## play-style picker, so the running game no longer shows a persistent "press
## 1-6 for a device" legend. This overlay brings that legend back on demand:
## the backtick (`) key toggles it, and only while it is open do the number
## keys hot-swap the active scheme (gated via InputRouter.hotswap_enabled).
##
## It exists so a playtester can rapidly compare devices on one station without
## the number-key chooser cluttering the HUD or firing by accident.

const ROWS := [
	[KEY_1, "1", "Keyboard / Mouse"],
	[KEY_2, "2", "Gamepad"],
	[KEY_3, "3", "Single Switch"],
	[KEY_4, "4", "Eye Tracking"],
	[KEY_5, "5", "Voice"],
	[KEY_6, "6", "AT Bridge (UDP)"],
]

var _current_label: Label

func _ready() -> void:
	layer = 30   # a playtest tool: above every overlay (selects, options menu)
	visible = false
	_build_ui()
	AssistSettings.changed.connect(_refresh_current)

func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	InputRouter.hotswap_enabled = true
	_refresh_current()

func close() -> void:
	visible = false
	InputRouter.hotswap_enabled = false

func _build_ui() -> void:
	# Centred card so it reads as a deliberate playtest tool, not part of the HUD.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.25, 0.7)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	vb.add_child(_line("DEVICE SWITCHER · playtest", 24, Color(1.0, 0.85, 0.25)))
	vb.add_child(_line("Press a number to swap the active input device:", 17, Color(0.82, 0.88, 0.98)))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for row in ROWS:
		grid.add_child(_line(row[1], 20, Color(1.0, 0.9, 0.5)))
		grid.add_child(_line(row[2], 20, Color(0.92, 0.95, 1.0)))

	_current_label = _line("", 18, Color(0.6, 0.95, 0.7))
	vb.add_child(_current_label)
	vb.add_child(_line("` (backtick) closes this overlay", 15, Color(0.7, 0.75, 0.82)))

func _refresh_current() -> void:
	if _current_label != null:
		_current_label.text = "Active: %s" % AssistSettings.scheme_label()

func _line(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
