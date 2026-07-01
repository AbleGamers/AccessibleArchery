extends Node3D
class_name Arrow
## A single fired arrow in 3D. Simple, deterministic, hand-integrated motion (no
## RigidBody) so the trajectory is easy to read, tune, and reason about. The
## mesh is built in code so the project needs no art assets yet.

## Emitted exactly once when the arrow's flight ends: the ring score on a hit,
## or 0 on a miss (left the play area). The match logic counts every shot,
## including misses, so this fires in both cases.
signal resolved(score: int)

@export var gravity: float = 14.0

var _velocity: Vector3 = Vector3.ZERO
var _flying: bool = false
var _resolved: bool = false

func _ready() -> void:
	_build_mesh()

func launch(velocity: Vector3) -> void:
	_velocity = velocity
	_flying = true
	if _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)

func _process(delta: float) -> void:
	if not _flying:
		return
	_velocity.y -= gravity * delta
	_velocity += Wind.accel() * delta        # dynamic wind drift
	global_position += _velocity * delta
	if _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)

	for target in get_tree().get_nodes_in_group("targets"):
		if global_position.distance_to(target.global_position) <= target.hit_radius():
			var score: int = target.register_hit(global_position)
			_finish(score)
			return

	# Despawn once it leaves the play area (a miss).
	if global_position.y < -5.0 or global_position.length() > 300.0:
		_finish(0)

func _finish(score: int) -> void:
	if _resolved:
		return
	_resolved = true
	_flying = false
	resolved.emit(score)
	queue_free()

func _build_mesh() -> void:
	# Shaft, long along local -Z (the flight direction).
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	shaft.mesh = box
	shaft.material_override = _flat_material(Color(0.95, 0.88, 0.65))
	add_child(shaft)

	# Red arrowhead (cone) at the front so the arrow is easy to track in flight.
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.08
	cone.height = 0.22
	head.mesh = cone
	head.material_override = _flat_material(Color(0.85, 0.20, 0.20))
	head.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)   # cone tip -> -Z
	head.position = Vector3(0.0, 0.0, -0.6)
	add_child(head)

	# Three fletchings at the tail.
	for i in 3:
		var fin := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.012, 0.13, 0.18)
		fin.mesh = fb
		fin.material_override = _flat_material(Color(0.90, 0.30, 0.20))
		fin.position = Vector3(0.0, 0.0, 0.42)
		fin.rotation = Vector3(0.0, 0.0, deg_to_rad(120.0 * i))
		add_child(fin)

func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
