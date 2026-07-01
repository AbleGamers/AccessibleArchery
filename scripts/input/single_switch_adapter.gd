extends InputAdapter
class_name SingleSwitchAdapter
## The lowest-bandwidth complete play loop: ONE input, the classic two-phase
## scanning pattern used by switch-access players.
##
##   1. SCAN_YAW   — the aim sweeps left/right. Tap the switch to lock horizontal.
##   2. SCAN_PITCH — the aim sweeps up/down.  Tap the switch to lock vertical.
##   3. DRAWING    — the bow charges and auto-looses at full draw, then resets.
##
## A player who can actuate only a single switch can play the entire game.

enum Phase { SCAN_YAW, SCAN_PITCH, DRAWING }

@export var sweep_speed: float = 0.5   # normalized units per second (× sensitivity)

var _phase: int = Phase.SCAN_YAW
var _x: float = 0.0
var _y: float = 0.0
var _t: float = 0.0
var _dir: float = 1.0
var _release_timer: float = 0.0
var _was_active: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.SINGLE_SWITCH

func _process(delta: float) -> void:
	var active := _is_active()
	if active and not _was_active:
		_reset()
	_was_active = active
	if not active:
		return

	match _phase:
		Phase.SCAN_YAW:
			_x = _sweep(delta)
			InputRouter.report_aim_absolute(self, Vector2(_x, _y))
			if _switch_pressed():
				_phase = Phase.SCAN_PITCH
				_t = 0.0
				_dir = 1.0
		Phase.SCAN_PITCH:
			_y = _sweep(delta)
			InputRouter.report_aim_absolute(self, Vector2(_x, _y))
			if _switch_pressed():
				_phase = Phase.DRAWING
				_release_timer = AssistSettings.full_draw_seconds + 0.15
				InputRouter.report_draw_pressed(self)
		Phase.DRAWING:
			_release_timer -= delta
			if _release_timer <= 0.0:
				InputRouter.report_draw_released(self)
				_reset()

func _sweep(delta: float) -> float:
	_t += _dir * sweep_speed * AssistSettings.aim_sensitivity * delta
	if _t > 1.0:
		_t = 1.0
		_dir = -1.0
	elif _t < -1.0:
		_t = -1.0
		_dir = 1.0
	return _t

func _switch_pressed() -> bool:
	return Input.is_action_just_pressed("draw") or Input.is_action_just_pressed("draw_pad")

func _reset() -> void:
	_phase = Phase.SCAN_YAW
	_x = 0.0
	_y = 0.0
	_t = 0.0
	_dir = 1.0
