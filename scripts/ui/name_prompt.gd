extends CanvasLayer
class_name NamePrompt
## A small modal overlay that asks the player to type a name, used the first time
## they bank a score. Confirm with Enter or OK, cancel with Esc. Processes while
## anything else is paused (it isn't, here) and grabs the text field on open.

var _root: Control
var _line: LineEdit
var _on_submit: Callable

func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func is_open() -> bool:
	return _root.visible

## Show the prompt; `on_submit` is called with the entered (non-empty) name.
func prompt(default_text: String, on_submit: Callable) -> void:
	_on_submit = on_submit
	_line.text = default_text
	_root.visible = true
	_line.grab_focus()
	_line.select_all()

func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_root.visible = false
		get_viewport().set_input_as_handled()

func _submit() -> void:
	var name := _line.text.strip_edges()
	if name == "":
		name = "Player"
	_root.visible = false
	if _on_submit.is_valid():
		_on_submit.call(name)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var heading := Label.new()
	heading.text = "Enter your name"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vb.add_child(heading)

	_line = LineEdit.new()
	_line.placeholder_text = "Name"
	_line.max_length = 16
	_line.add_theme_font_size_override("font_size", 22)
	_line.text_submitted.connect(func(_t): _submit())
	vb.add_child(_line)

	var ok := Button.new()
	ok.text = "Save to leaderboard"
	ok.pressed.connect(_submit)
	vb.add_child(ok)
