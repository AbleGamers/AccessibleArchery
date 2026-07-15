extends Node3D
class_name ImpactCam
## Broadcast-style "target cam" (the GDD's cinematic release feedback): when an
## arrow is loosed, cut to a camera planted beside the target watching the arrow
## fly in, hold a beat on the impact, then cut back to the player's camera.
## Deliberately built from hard CUTS with a static camera — no swooping motion —
## so it stays comfortable for motion-sensitive players; it can also be disabled
## entirely via AssistSettings.impact_cam_enabled. Pure presentation: input and
## gameplay continue underneath.

const HOLD_SECONDS := 0.9      # linger on the impact before cutting back
const TIMEOUT := 4.0           # absolute cap, so a stray arrow can't strand us

var _cam: Camera3D
var _prev: Camera3D
var _arrow: Node3D
var _elapsed := 0.0
var _holding := 0.0
var _active := false

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)

## Cut to the target-side view and track this arrow until it lands (+ hold).
func follow(arrow: Node3D, target: Node3D) -> void:
	if arrow == null or target == null:
		return
	var anchor := target.global_position
	var back := (arrow.global_position - anchor).normalized()
	var side := back.cross(Vector3.UP).normalized()
	# Beside and in front of the target face, looking back up the arrow's line.
	_cam.global_position = anchor + back * 3.2 + side * 2.4 + Vector3.UP * 1.1
	_arrow = arrow
	_elapsed = 0.0
	_holding = 0.0
	_active = true
	arrow.resolved.connect(_on_arrow_resolved.bind(arrow), CONNECT_ONE_SHOT)
	if not _cam.current:
		_prev = get_viewport().get_camera_3d()
		_cam.make_current()

func _on_arrow_resolved(_score: int, _offset: Vector2, arrow: Node3D) -> void:
	if arrow == _arrow:
		_holding = HOLD_SECONDS

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if is_instance_valid(_arrow):
		_cam.look_at(_arrow.global_position, Vector3.UP)
	if _holding > 0.0:
		_holding -= delta
		if _holding <= 0.0:
			_restore()
	elif _elapsed >= TIMEOUT:
		_restore()

func _restore() -> void:
	_active = false
	_arrow = null
	if is_instance_valid(_prev):
		_prev.make_current()
	else:
		_cam.current = false
	_prev = null
