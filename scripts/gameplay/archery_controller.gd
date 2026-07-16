extends Node3D
class_name ArcheryController
## The bow, in 3D. Consumes device-agnostic intents from the InputRouter and
## turns them into yaw/pitch aim and a fired arrow. Knows NOTHING about specific
## devices — that is the whole point.
##
## Two aim modes are supported transparently:
##   * aim_axis     — integrated over time (rate steering: keys, sticks, voice)
##   * aim_absolute — set directly (point-to-aim: eye tracking, switch scan)
##
## Third-person over-the-shoulder rig: the controller node YAWS (turning the
## whole archer and the camera), while a child `_aim_pivot` PITCHES (raising just
## the bow arm). The camera sits behind/above the shoulder. A low-poly archer is
## built in code so there are still no art assets.

signal aim_updated(aim_norm: Vector2, charge: float)
signal arrow_fired(arrow: Node)
## The ring score (0 on a miss) of a shot once its flight resolves, plus where
## it struck relative to the face centre in face radii (see Arrow.resolved).
## Match logic tallies the score; the impact audio pans by the offset.
signal shot_resolved(score: int, offset: Vector2)
## Emitted once each draw when charge first reaches full — drives the Second
## Channel "draw-snap" cue (visual flash, audio, haptic pulse).
signal full_draw_reached
## Emitted when a draw is released before full and so does not loose — drives the
## "draw cancelled" feedback so the player understands why nothing fired.
signal draw_cancelled
## Emitted when held breath engages at full draw and the reticle snaps steady.
signal steady_started
## Emitted once per draw when the held breath runs out — sway is now ramping.
signal breath_exhausted

const ARROW_SCENE := preload("res://scenes/arrow.tscn")

# One shared aim envelope so every device reaches the SAME angles, and the same
# steering speed for both rate devices — no device gets more reach or speed.
@export var turn_speed: float = deg_to_rad(55.0)         # rate steering, rad/s
@export var yaw_limit: float = deg_to_rad(55.0)
@export var pitch_limit: float = deg_to_rad(32.0)
@export var absolute_yaw_range: float = deg_to_rad(55.0)
@export var absolute_pitch_range: float = deg_to_rad(32.0)
@export var max_launch_speed: float = 48.0
## A shot only looses at (essentially) full draw; manual release before this just
## cancels. Keeps every shot a full-power full-draw, identical across devices.
const FULL_DRAW_THRESHOLD := 0.97

## --- Sway & breath (the GDD's draw-tension / hold-breath loop) ---------------
## Sway builds while the string is pulled (pure tension: pre-full-draw releases
## cancel, so it can never touch a shot). At full draw, held breath — automatic
## by default, or the `steady` intent — SNAPS the reticle steady; while breath
## lasts, sway is exactly zero, so a switch/eye auto-loose and a well-timed
## manual release are identical. Over-hold past the breath and sway returns,
## growing harder and faster. Amplitude scales with AssistSettings.sway_scale
## (0 = always steady). Sway rotates only the aim pivot — never the camera.
const SWAY_BASE := deg_to_rad(1.3)      # amplitude at full charge, unsteadied
const OVERHOLD_GROWTH := 2.2            # amplitude growth per second over-held

var _yaw: float = 0.0
var _pitch: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _drawing: bool = false
var _charge: float = 0.0

var _sway: Vector2 = Vector2.ZERO       # (yaw, pitch) offsets, radians
var _sway_amp: float = 0.0
var _sway_t: float = 0.0
var _breath: float = 0.0                # seconds of steadying left this draw
var _overhold: float = 0.0              # seconds spent unsteadied at full draw
var _steady_input: bool = false         # manual `steady` intent held
var _was_steady: bool = false
var _exhausted: bool = false

var _aim_pivot: Node3D   # pitches with elevation; holds the bow + arms
var _camera: Camera3D

# The selected athlete's model (body on self, arms on the pivot), rebuilt when
# the roster selection changes.
var _athlete_root: Node3D
var _arm_root: Node3D
var _built_athlete: int = -1

# Draw-pose animation refs & state: the draw arm/hand track the string, the
# body leans into the draw, the head tilts, and release kicks a brief recoil.
var _head_pivot: Node3D
var _draw_arm: MeshInstance3D
var _draw_hand: MeshInstance3D
var _anim_charge: float = 0.0   # smoothed charge, drives lean/tilt
var _recoil: float = 0.0        # decaying release impulse

# First-person bow visual (built in code, no art assets). Held in the lower-left
# of view; the string + nocked arrow pull back as the draw charges.
var _bow_root: Node3D
var _string_upper: MeshInstance3D
var _string_lower: MeshInstance3D
var _nocked_arrow: Node3D
const BOW_TIP_Y := 0.30          # upper limb tip height (lower is mirrored)
const BOW_TIP_Z := -0.06         # limb tips sit slightly forward of the grip
const BOW_REST_Z := 0.02         # string nock position at rest
const BOW_MAX_PULL := 0.20       # how far a full draw pulls the nock back

func _ready() -> void:
	# Pitch pivot (raises the bow arm without tilting the body).
	_aim_pivot = Node3D.new()
	add_child(_aim_pivot)

	# Over-the-shoulder camera: behind, above, and to the right of the archer,
	# tilted slightly down the range. A child of the controller, so it turns
	# with yaw and keeps the archer framed from behind.
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true
	_apply_camera_side()
	AssistSettings.changed.connect(_apply_camera_side)

	_build_athlete()
	AssistSettings.changed.connect(_build_athlete)

	InputRouter.aim_axis.connect(_on_aim_axis)
	InputRouter.aim_absolute.connect(_on_aim_absolute)
	InputRouter.draw_pressed.connect(_on_draw_pressed)
	InputRouter.draw_released.connect(_on_draw_released)
	InputRouter.steady_pressed.connect(func(): _steady_input = true)
	InputRouter.steady_released.connect(func(): _steady_input = false)
	_apply_rotation()
	_build_bow()

func is_drawing() -> bool:
	return _drawing

func _on_aim_axis(axis: Vector2) -> void:
	if InputRouter.captured_by_ui:
		return
	_axis = axis

func _on_aim_absolute(position: Vector2) -> void:
	if InputRouter.captured_by_ui:
		return
	# Right (+x) should turn the aim toward +X, which is a negative yaw.
	_yaw = clampf(-position.x * absolute_yaw_range, -yaw_limit, yaw_limit)
	_pitch = clampf(position.y * absolute_pitch_range, -pitch_limit, pitch_limit)
	_axis = Vector2.ZERO
	_apply_rotation()
	_emit()

func _on_draw_pressed() -> void:
	if InputRouter.captured_by_ui:
		return
	_drawing = true
	_charge = 0.0
	_breath = AssistSettings.breath_seconds
	_overhold = 0.0
	_was_steady = false
	_exhausted = false

func _on_draw_released() -> void:
	if not _drawing:
		return
	_drawing = false
	# Every shot is a full draw at full power, so the input method never changes
	# the arrow. Releasing before full draw cancels — there are no weak partial
	# shots that a manual device could exploit (or fumble) over a hands-free one.
	if _charge >= FULL_DRAW_THRESHOLD:
		_fire()
	else:
		_charge = 0.0
		draw_cancelled.emit()
		_emit()

func _process(delta: float) -> void:
	if InputRouter.captured_by_ui:
		# A UI overlay owns the intents: stop steering and quietly let any
		# half-drawn shot down (no cancel feedback — the player is in a menu).
		_axis = Vector2.ZERO
		if _drawing:
			_drawing = false
			_charge = 0.0
			_emit()
	var changed := false
	if _axis != Vector2.ZERO:
		var step := turn_speed * AssistSettings.aim_sensitivity * _precision_factor() * delta
		_yaw = clampf(_yaw - _axis.x * step, -yaw_limit, yaw_limit)
		_pitch = clampf(_pitch - _axis.y * step, -pitch_limit, pitch_limit)
		_apply_rotation()
		changed = true
	if _drawing:
		var rate := 1.0 / maxf(AssistSettings.full_draw_seconds, 0.05)
		var before := _charge
		_charge = clampf(_charge + rate * delta, 0.0, 1.0)
		if before < 1.0 and _charge >= 1.0:
			full_draw_reached.emit()
		changed = true
	_update_sway(delta)
	if changed:
		_emit()
	_update_bow()
	_update_pose(delta)

## The draw pose: the string hand tracks the nock exactly (same pull maths as
## the string), while lean and head-tilt follow a smoothed charge so the whole
## athlete settles into the draw — and a recoil impulse rocks them on release.
func _update_pose(delta: float) -> void:
	_anim_charge = lerpf(_anim_charge, _charge if _drawing else 0.0, clampf(10.0 * delta, 0.0, 1.0))
	_recoil = lerpf(_recoil, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	if _athlete_root != null:
		_athlete_root.rotation_degrees = Vector3(
			-3.0 * _anim_charge + 5.0 * _recoil, 0.0, 1.5 * _anim_charge)
	if _head_pivot != null:
		_head_pivot.rotation_degrees = Vector3(2.0 * _anim_charge, 0.0, 8.0 * _anim_charge)
	if _draw_arm != null and _draw_hand != null:
		var pull := (_charge if _drawing else 0.0) * BOW_MAX_PULL
		# Same offsets as the bow: bow_root at z -0.62 (scale 2), nock at
		# BOW_REST_Z + pull  →  pivot-space z = -0.58 + 2·pull.
		var hand := Vector3(0.0, 0.0, -0.58 + 2.0 * pull)
		_orient_segment(_draw_arm, Vector3(0.20, -0.02, 0.05), hand)
		_draw_hand.position = hand

# The sway & breath state machine (see the block comment at SWAY_BASE).
func _update_sway(delta: float) -> void:
	var target_amp := 0.0
	if _drawing:
		if _charge >= 1.0:
			var steady := false
			# Hands-free devices (no steady intent) always get auto-hold.
			var wants := _steady_input or AssistSettings.auto_hold_breath \
				or not InputRouter.steady_supported()
			if wants and not _exhausted:
				steady = true
				if not _was_steady:
					_was_steady = true
					steady_started.emit()
				if not AssistSettings.unlimited_time:
					_breath -= delta
					if _breath <= 0.0:
						_exhausted = true
						breath_exhausted.emit()
			if not steady:
				_overhold += delta
				target_amp = SWAY_BASE * (1.0 + OVERHOLD_GROWTH * _overhold)
		else:
			target_amp = SWAY_BASE * _charge   # tension builds with the pull
	target_amp *= AssistSettings.sway_scale
	# Snap down fast (the "steady" beat reads as a lock), grow back smoothly.
	var k := 14.0 if target_amp < _sway_amp else 4.0
	_sway_amp = lerpf(_sway_amp, target_amp, clampf(k * delta, 0.0, 1.0))
	# Over-holding speeds the wobble up as well as widening it.
	_sway_t += delta * (1.2 + 0.8 * _overhold)
	if _sway_amp > 0.00005:
		_sway = Vector2(
			_sway_amp * (0.6 * sin(_sway_t * 2.3) + 0.4 * sin(_sway_t * 5.1 + 1.7)),
			_sway_amp * (0.6 * sin(_sway_t * 2.9 + 0.8) + 0.4 * sin(_sway_t * 4.3 + 2.4)))
		_apply_rotation()
	elif _sway != Vector2.ZERO:
		_sway = Vector2.ZERO
		_apply_rotation()

## 0..1: how unsteady the aim is right now, relative to base sway — feeds the
## audio-tone wobble and haptics so instability is perceivable without sight.
func sway_instability() -> float:
	return clampf(_sway_amp / (SWAY_BASE * 2.0), 0.0, 1.0)

## Remaining held-breath fraction (1 = full), for HUD / captions.
func breath_fraction() -> float:
	return clampf(_breath / maxf(AssistSettings.breath_seconds, 0.001), 0.0, 1.0)

func is_steady() -> bool:
	return _drawing and _charge >= 1.0 and _was_steady and not _exhausted

func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)              # body + camera turn
	if _aim_pivot != null:
		# Sway wobbles only the aim pivot (bow arm), NEVER the camera — the view
		# stays rock steady for motion-sensitive players while the reticle drifts.
		_aim_pivot.rotation = Vector3(_pitch + _sway.y, _sway.x, 0.0)

## World-space direction the bow is aiming (used by the audio/haptic cues).
func aim_forward() -> Vector3:
	if _aim_pivot == null:
		return -global_transform.basis.z
	return -_aim_pivot.global_transform.basis.z

## World-space right axis of the body (for left/right cue panning).
func right_axis() -> Vector3:
	return global_transform.basis.x

# Places the 3/4 side camera on whichever side AssistSettings selects. A narrow
# FOV (telephoto) keeps the archer waist-up — at a wide FOV a true waist-up side
# view would need the camera almost on top of them.
func _apply_camera_side() -> void:
	if _camera == null:
		return
	var sx := -1.0 if AssistSettings.camera_on_left else 1.0
	_camera.fov = 46.0
	_camera.position = Vector3(0.95 * sx, 0.34, 1.55)
	_camera.rotation_degrees = Vector3(-7.5, 22.0 * sx, 0.0)

func _emit() -> void:
	# Normalized so positive x = aiming right, positive y = aiming up.
	aim_updated.emit(Vector2(clampf(-_yaw / yaw_limit, -1.0, 1.0), clampf(_pitch / pitch_limit, -1.0, 1.0)), _charge)

func _fire() -> void:
	var forward := aim_forward().normalized()
	forward = _apply_aim_assist(forward)
	var arrow := ARROW_SCENE.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position + forward * 0.6
	arrow.launch(forward * max_launch_speed)   # always full power — charge never alters the shot
	arrow.resolved.connect(func(score: int, offset: Vector2): shot_resolved.emit(score, offset))
	arrow_fired.emit(arrow)
	_charge = 0.0
	_recoil = 1.0
	_emit()

func _apply_aim_assist(dir: Vector3) -> Vector3:
	var assist := AssistSettings.aim_assist
	if assist <= 0.0:
		return dir
	var to_target := _nearest_target_dir()
	if to_target == Vector3.ZERO:
		return dir
	return dir.lerp(to_target, assist).normalized()

## Device-agnostic fine aim: rate steering slows as the aim closes on a target,
## so coarse sweeps stay quick but the last few degrees are precise. The scale
## comes from AssistSettings.precision_slowdown and applies to every rate device
## identically — parity between devices is preserved. The cone is the shared
## AssistSettings.guidance_cone_deg, so it matches the audio/haptic targeting.
func _precision_factor() -> float:
	var slow := AssistSettings.precision_slowdown
	if slow <= 0.0:
		return 1.0
	var to_target := _nearest_target_dir()
	if to_target == Vector3.ZERO:
		return 1.0
	var angle := acos(clampf(aim_forward().normalized().dot(to_target), -1.0, 1.0))
	var closeness := clampf(1.0 - angle / deg_to_rad(AssistSettings.guidance_cone_deg), 0.0, 1.0)
	return 1.0 - slow * closeness

## Unit direction to the target nearest the current aim (ZERO if none) — shared
## by the precision zone and aim assist, so both act on the target the player is
## actually working, not merely the first one in the scene.
func _nearest_target_dir() -> Vector3:
	var forward := aim_forward().normalized()
	var best := Vector3.ZERO
	var best_dot := -1.0
	for target in get_tree().get_nodes_in_group("targets"):
		var to: Vector3 = (target.global_position - global_position).normalized()
		var d := forward.dot(to)
		if d > best_dot:
			best_dot = d
			best = to
	return best

# --- First-person bow visual --------------------------------------------------

func _build_bow() -> void:
	_bow_root = Node3D.new()
	# Held in the archer's bow hand, out in front of the shoulder. A child of the
	# pitch pivot, so it rises and falls with elevation.
	_aim_pivot.add_child(_bow_root)
	_bow_root.position = Vector3(-0.05, 0.0, -0.62)
	_bow_root.scale = Vector3(2.0, 2.0, 2.0)   # a real, visible bow (~1.2 m)

	var wood := Color(0.45, 0.28, 0.12)
	var string_col := Color(0.92, 0.92, 0.92)
	var top_tip := Vector3(0.0, BOW_TIP_Y, BOW_TIP_Z)
	var bot_tip := Vector3(0.0, -BOW_TIP_Y, BOW_TIP_Z)

	# Riser (grip) + two limbs curving forward to the tips.
	_bow_root.add_child(_segment(Vector3(0, -0.16, 0), Vector3(0, 0.16, 0), 0.022, wood))
	_bow_root.add_child(_segment(Vector3(0, 0.16, 0), top_tip, 0.016, wood))
	_bow_root.add_child(_segment(Vector3(0, -0.16, 0), bot_tip, 0.016, wood))

	# Bowstring = two thin segments meeting at the nock point (moved each frame).
	_string_upper = _segment(top_tip, Vector3(0, 0, BOW_REST_Z), 0.005, string_col)
	_string_lower = _segment(bot_tip, Vector3(0, 0, BOW_REST_Z), 0.005, string_col)
	_bow_root.add_child(_string_upper)
	_bow_root.add_child(_string_lower)

	# Nocked arrow rides the string and pulls back with charge. Built by the
	# same function as the flight arrow, so what's on the string is exactly
	# what lands in the target (bow_root is scaled 2x, hence the half length).
	_nocked_arrow = Node3D.new()
	Arrow.build_visual(_nocked_arrow, 0.55)
	_bow_root.add_child(_nocked_arrow)
	_update_bow()

func _update_bow() -> void:
	if _bow_root == null:
		return
	var pull := (_charge * BOW_MAX_PULL) if _drawing else 0.0
	var nock := Vector3(0.0, 0.0, BOW_REST_Z + pull)
	_orient_segment(_string_upper, Vector3(0.0, BOW_TIP_Y, BOW_TIP_Z), nock)
	_orient_segment(_string_lower, Vector3(0.0, -BOW_TIP_Y, BOW_TIP_Z), nock)
	# Tail (nock end, +0.275 of the 0.55 arrow) sits on the string.
	_nocked_arrow.position = nock + Vector3(0.0, 0.0, -0.275)

# A unit-radius cylinder oriented to span from a -> b in the parent's space.
func _segment(a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.radial_segments = 8
	mi.mesh = cyl
	mi.material_override = _flat_material(color)
	_orient_segment(mi, a, b)
	return mi

func _orient_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var cyl: CylinderMesh = mi.mesh
	var d := b - a
	var length := d.length()
	cyl.height = maxf(length, 0.0001)
	var y := d.normalized() if length > 0.00001 else Vector3.UP
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

# --- The selected athlete (seen from behind in the OTS camera) ----------------
# Models come from AthleteRoster (four archetypes, including wheelchair
# athletes). Only the visuals and shooting height differ — the aim envelope is
# identical for every athlete.

func _build_athlete() -> void:
	if _built_athlete == AssistSettings.athlete_index:
		return
	_built_athlete = AssistSettings.athlete_index
	if _athlete_root != null:
		_athlete_root.queue_free()
	if _arm_root != null:
		_arm_root.queue_free()
	_athlete_root = Node3D.new()
	add_child(_athlete_root)
	_arm_root = Node3D.new()
	_aim_pivot.add_child(_arm_root)
	var def := AthleteRoster.get_def(AssistSettings.athlete_index)
	var body_refs := AthleteRoster.build_body(_athlete_root, def)
	var arm_refs := AthleteRoster.build_arms(_arm_root, def)
	_head_pivot = body_refs.get("head")
	_draw_arm = arm_refs.get("draw_arm")
	_draw_hand = arm_refs.get("draw_hand")
