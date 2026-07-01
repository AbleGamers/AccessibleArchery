extends InputAdapter
class_name GamepadAdapter
## Steer aim with the left stick (rate-based); hold A to draw; release to fire.
##
## Note: the Xbox Adaptive Controller and most assistive joysticks enumerate as
## standard gamepads, so they work through this adapter with no extra code.

func _init() -> void:
	scheme = AssistSettings.InputScheme.GAMEPAD

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
	if Input.is_action_just_pressed("draw_pad"):
		InputRouter.report_draw_pressed(self)
	if Input.is_action_just_released("draw_pad"):
		InputRouter.report_draw_released(self)
