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
## The ring score (0 on a miss) of a shot once its flight resolves. Match logic
## listens to this to tally the player's arrows.
signal shot_resolved(score: int)
## Emitted once each draw when charge first reaches full — drives the Second
## Channel "draw-snap" cue (visual flash, audio, haptic pulse).
signal full_draw_reached
## Emitted when a draw is released before full and so does not loose — drives the
## "draw cancelled" feedback so the player understands why nothing fired.
signal draw_cancelled

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

var _yaw: float = 0.0
var _pitch: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _drawing: bool = false
var _charge: float = 0.0

var _aim_pivot: Node3D   # pitches with elevation; holds the bow + arms
var _camera: Camera3D

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

	_build_archer()

	InputRouter.aim_axis.connect(_on_aim_axis)
	InputRouter.aim_absolute.connect(_on_aim_absolute)
	InputRouter.draw_pressed.connect(_on_draw_pressed)
	InputRouter.draw_released.connect(_on_draw_released)
	_apply_rotation()
	_build_bow()

func is_drawing() -> bool:
	return _drawing

func _on_aim_axis(axis: Vector2) -> void:
	_axis = axis

func _on_aim_absolute(position: Vector2) -> void:
	# Right (+x) should turn the aim toward +X, which is a negative yaw.
	_yaw = clampf(-position.x * absolute_yaw_range, -yaw_limit, yaw_limit)
	_pitch = clampf(position.y * absolute_pitch_range, -pitch_limit, pitch_limit)
	_axis = Vector2.ZERO
	_apply_rotation()
	_emit()

func _on_draw_pressed() -> void:
	_drawing = true
	_charge = 0.0

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
	var changed := false
	if _axis != Vector2.ZERO:
		var step := turn_speed * AssistSettings.aim_sensitivity * delta
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
	if changed:
		_emit()
	_update_bow()

func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)              # body + camera turn
	if _aim_pivot != null:
		_aim_pivot.rotation = Vector3(_pitch, 0.0, 0.0)  # bow arm elevates

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
	arrow.resolved.connect(func(score: int): shot_resolved.emit(score))
	arrow_fired.emit(arrow)
	_charge = 0.0
	_emit()

func _apply_aim_assist(dir: Vector3) -> Vector3:
	var assist := AssistSettings.aim_assist
	if assist <= 0.0:
		return dir
	var target := get_tree().get_first_node_in_group("targets")
	if target == null:
		return dir
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	return dir.lerp(to_target, assist).normalized()

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

	# Nocked arrow rides the string and pulls back with charge.
	_nocked_arrow = _make_arrow_visual(0.6, 0.03, 0.05)
	_bow_root.add_child(_nocked_arrow)
	_update_bow()

func _update_bow() -> void:
	if _bow_root == null:
		return
	var pull := (_charge * BOW_MAX_PULL) if _drawing else 0.0
	var nock := Vector3(0.0, 0.0, BOW_REST_Z + pull)
	_orient_segment(_string_upper, Vector3(0.0, BOW_TIP_Y, BOW_TIP_Z), nock)
	_orient_segment(_string_lower, Vector3(0.0, -BOW_TIP_Y, BOW_TIP_Z), nock)
	_nocked_arrow.position = nock + Vector3(0.0, 0.0, -0.30)

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

# A small arrow visual (shaft + cone head) pointing along local -Z.
func _make_arrow_visual(length: float, shaft_w: float, head_r: float) -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(shaft_w, shaft_w, length)
	shaft.mesh = box
	shaft.material_override = _flat_material(Color(0.95, 0.90, 0.70))
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = head_r
	cone.height = head_r * 2.6
	head.mesh = cone
	head.material_override = _flat_material(Color(0.80, 0.80, 0.85))
	head.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)   # cone tip -> -Z
	head.position = Vector3(0.0, 0.0, -length * 0.5 - head_r)
	root.add_child(head)
	return root

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

# --- Low-poly archer (seen from behind in the OTS camera) ---------------------

func _build_archer() -> void:
	var skin := Color(0.86, 0.67, 0.52)
	var outfit := Color(0.20, 0.45, 0.55)
	var dark := Color(0.16, 0.19, 0.24)

	# Origin sits at shoulder height (the controller is placed at eye/shoulder
	# height), so the body hangs below and the head sits just above.
	var head := SphereMesh.new()
	head.radius = 0.12
	head.height = 0.24
	_solid(self, head, Vector3(0.0, 0.30, 0.02), skin)

	var torso := BoxMesh.new()
	torso.size = Vector3(0.42, 0.72, 0.24)
	_solid(self, torso, Vector3(0.0, -0.18, 0.0), outfit)

	var hips := BoxMesh.new()
	hips.size = Vector3(0.40, 0.20, 0.24)
	_solid(self, hips, Vector3(0.0, -0.62, 0.0), dark)

	for side in [-1.0, 1.0]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.16, 0.95, 0.18)
		_solid(self, leg, Vector3(0.11 * side, -1.15, 0.0), dark)

	# Arms live under the pitch pivot so they raise with the bow. Bow arm reaches
	# forward to the grip; draw arm pulls back toward the face.
	_aim_pivot.add_child(_segment(Vector3(-0.20, 0.0, 0.0), Vector3(-0.06, 0.0, -0.55), 0.05, outfit))
	_aim_pivot.add_child(_segment(Vector3(0.20, 0.0, 0.0), Vector3(0.06, 0.04, 0.14), 0.05, outfit))

func _solid(parent: Node, mesh: Mesh, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
