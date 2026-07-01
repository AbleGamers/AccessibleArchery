extends InputAdapter
class_name KeyboardMouseAdapter
## Steer aim with arrow keys / WASD (rate-based); hold Space (or Enter) to draw;
## release to fire.

func _init() -> void:
	scheme = AssistSettings.InputScheme.KEYBOARD_MOUSE

func _process(_delta: float) -> void:
	if not _is_active():
		return
	InputRouter.report_aim_axis(self, Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down"))
	if Input.is_action_just_pressed("draw"):
		InputRouter.report_draw_pressed(self)
	if Input.is_action_just_released("draw"):
		InputRouter.report_draw_released(self)
