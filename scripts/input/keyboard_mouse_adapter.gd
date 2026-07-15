extends InputAdapter
class_name KeyboardMouseAdapter
## Steer aim with arrow keys / WASD (rate-based); hold Space (or Enter) to draw,
## release to fire — or, with AssistSettings.toggle_draw, tap once to draw and
## tap again to loose (no sustained hold). Hold Shift to steady (hold breath) at
## full draw when auto-hold is off.

var _toggle_drawn: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.KEYBOARD_MOUSE

func supports_steady() -> bool:
	return true

func _process(_delta: float) -> void:
	if not _is_active():
		return
	InputRouter.report_aim_axis(self, Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down"))

	if AssistSettings.toggle_draw:
		if Input.is_action_just_pressed("draw"):
			if _toggle_drawn:
				InputRouter.report_draw_released(self)
				_toggle_drawn = false
			else:
				InputRouter.report_draw_pressed(self)
				_toggle_drawn = true
	else:
		_toggle_drawn = false
		if Input.is_action_just_pressed("draw"):
			InputRouter.report_draw_pressed(self)
		if Input.is_action_just_released("draw"):
			InputRouter.report_draw_released(self)

	if Input.is_action_just_pressed("steady"):
		InputRouter.report_steady_pressed(self)
	if Input.is_action_just_released("steady"):
		InputRouter.report_steady_released(self)
