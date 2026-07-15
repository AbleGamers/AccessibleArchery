extends InputAdapter
class_name GamepadAdapter
## Steer aim with the left stick (rate-based); hold A to draw, release to fire —
## or, with AssistSettings.toggle_draw, tap A once to draw and tap again to
## loose. Hold X to steady (hold breath) at full draw when auto-hold is off.
##
## Note: the Xbox Adaptive Controller and most assistive joysticks enumerate as
## standard gamepads, so they work through this adapter with no extra code.

var _toggle_drawn: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.GAMEPAD

func supports_steady() -> bool:
	return true

func _process(_delta: float) -> void:
	if not _is_active():
		return
	# Past the deadzone, steer in the stick's DIRECTION at the full fixed rate —
	# identical to the keyboard. Deliberate fairness: an analog stick must not
	# grant finer aim control than a key, so we ignore stick magnitude.
	var v := Input.get_vector("pad_aim_left", "pad_aim_right", "pad_aim_up", "pad_aim_down", 0.25)
	if v.length() > 0.0:
		v = v.normalized()
	InputRouter.report_aim_axis(self, v)

	if AssistSettings.toggle_draw:
		if Input.is_action_just_pressed("draw_pad"):
			if _toggle_drawn:
				InputRouter.report_draw_released(self)
				_toggle_drawn = false
			else:
				InputRouter.report_draw_pressed(self)
				_toggle_drawn = true
	else:
		_toggle_drawn = false
		if Input.is_action_just_pressed("draw_pad"):
			InputRouter.report_draw_pressed(self)
		if Input.is_action_just_released("draw_pad"):
			InputRouter.report_draw_released(self)

	if Input.is_action_just_pressed("steady_pad"):
		InputRouter.report_steady_pressed(self)
	if Input.is_action_just_released("steady_pad"):
		InputRouter.report_steady_released(self)
