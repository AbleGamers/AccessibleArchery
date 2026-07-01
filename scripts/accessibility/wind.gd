extends Node
## Dynamic wind. Autoloaded as `Wind`.
##
## Wind is a shared gameplay variable that the GDD surfaces on ALL three Second
## Channel outputs at once: visually (an on-screen indicator), audibly (it shifts
## the centering cue), and haptically (felt as rumble). This node owns only the
## simulation; the cue systems read from it.
##
## The wind drifts smoothly toward a new random target every few seconds and
## emits `shifted` at each change so the caption/announcer can call it out.

signal shifted(lateral: float, speed_kmh: float)

@export var max_speed_kmh: float = 18.0
@export var change_interval: float = 6.0

var _lateral: float = 0.0          # smoothed, -1 (left) .. +1 (right)
var _speed_kmh: float = 0.0        # smoothed current speed
var _target_lateral: float = 0.0
var _target_speed: float = 0.0
var _timer: float = 0.0

func _ready() -> void:
	randomize()
	_pick_new_target()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_pick_new_target()
	_lateral = move_toward(_lateral, _target_lateral, delta * 0.6)
	_speed_kmh = move_toward(_speed_kmh, _target_speed, delta * 6.0)

func lateral() -> float:
	return _lateral

func speed_kmh() -> float:
	return _speed_kmh

## World-space acceleration applied to an arrow in flight (mostly lateral).
func accel() -> Vector3:
	if not AssistSettings.wind_enabled:
		return Vector3.ZERO
	var mps := _speed_kmh / 3.6
	return Vector3(_lateral * mps * 0.25, 0.0, 0.0) * AssistSettings.wind_scale

func _pick_new_target() -> void:
	_timer = change_interval
	_target_lateral = randf_range(-1.0, 1.0)
	_target_speed = randf_range(0.0, max_speed_kmh)
	shifted.emit(_target_lateral, _target_speed)
