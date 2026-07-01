extends InputAdapter
class_name EyeTrackingAdapter
## Hands-free aiming by gaze.
##
## Many eye trackers (Tobii, Windows Eye Control, eViacam, etc.) already drive
## the system cursor, so reading the pointer position gives us gaze for free.
## For dedicated hardware, replace _get_gaze_normalized() with a direct SDK
## feed (e.g. Tobii Stream Engine) — nothing else in the game changes.
##
## Loop: look to aim; hold your gaze still ("dwell") to start the draw; the shot
## auto-looses at full draw. A physical switch can also start the draw, for
## players who pair gaze with a switch.

@export var dwell_seconds: float = 0.6
@export var dwell_radius: float = 0.06   # normalized screen units
## Smoothing toward the raw gaze. Real eye trackers are jittery, and a raw mouse
## stand-in would otherwise be pixel-perfect — an unfair fine-aim advantage. This
## damps both so gaze aim is steady and comparable to the other devices.
@export var smooth_speed: float = 11.0

var _drawing: bool = false
var _dwell: float = 0.0
var _anchor: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.ZERO
var _release_timer: float = 0.0
var _was_active: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.EYE_TRACKING

func _process(delta: float) -> void:
	var active := _is_active()
	if active and not _was_active:
		_cancel()
	_was_active = active
	if not active:
		return

	var gaze := _get_gaze_normalized()
	_aim = _aim.lerp(gaze, clampf(smooth_speed * delta, 0.0, 1.0))
	InputRouter.report_aim_absolute(self, _aim)

	# Optional paired physical switch.
	if Input.is_action_just_pressed("draw"):
		_begin_draw()
	if Input.is_action_just_released("draw") and _drawing:
		_end_draw()

	if _drawing:
		_release_timer -= delta
		if _release_timer <= 0.0:
			_end_draw()
	else:
		# Dwell detection: smoothed gaze held within dwell_radius for dwell_seconds.
		if _aim.distance_to(_anchor) <= dwell_radius:
			_dwell += delta
			if _dwell >= dwell_seconds:
				_begin_draw()
		else:
			_dwell = 0.0
			_anchor = _aim

func _begin_draw() -> void:
	if _drawing:
		return
	_drawing = true
	_dwell = 0.0
	_release_timer = AssistSettings.full_draw_seconds + 0.15
	InputRouter.report_draw_pressed(self)

func _end_draw() -> void:
	if not _drawing:
		return
	_drawing = false
	_anchor = _get_gaze_normalized()
	InputRouter.report_draw_released(self)

func _cancel() -> void:
	_drawing = false
	_dwell = 0.0
	_aim = _get_gaze_normalized()
	_anchor = _aim

func _get_gaze_normalized() -> Vector2:
	# Stand-in: system pointer position mapped to [-1, 1]. Replace with an eye-
	# tracker SDK feed for dedicated hardware.
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var size := vp.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var m := vp.get_mouse_position()
	var nx := clampf(m.x / size.x * 2.0 - 1.0, -1.0, 1.0)
	var ny := clampf(m.y / size.y * 2.0 - 1.0, -1.0, 1.0)
	# Screen-up should aim up, so invert Y.
	return Vector2(nx, -ny)
