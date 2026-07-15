extends Node3D
class_name Arrow
## A single fired arrow in 3D. Simple, deterministic, hand-integrated motion (no
## RigidBody) so the trajectory is easy to read, tune, and reason about. The
## mesh is built in code so the project needs no art assets.
##
## Presentation: a faint particle trail in flight, then the arrow STICKS where
## it lands (target face or ground) and lingers before despawning, with an
## impact burst coloured by the ring it hit. CPU particles on purpose — the
## project ships on the GL Compatibility renderer for low-end venue PCs.

## Emitted exactly once when the arrow's flight ends: the ring score on a hit,
## or 0 on a miss (hit the ground / left the play area). The match logic counts
## every shot, including misses, so this fires in both cases. `offset` is where
## the arrow struck relative to the target face's centre, in face radii
## (+x = right of centre from the archer's view, +y = above; ZERO on a miss) —
## it drives the panned impact audio, so a blind player hears WHERE they hit.
signal resolved(score: int, offset: Vector2)

@export var gravity: float = 14.0

const STICK_SECONDS := 8.0        # a landed arrow stays visible this long
const EMBED_DEPTH := 0.18         # how far the head sinks into what it hit

var _velocity: Vector3 = Vector3.ZERO
var _flying: bool = false
var _resolved: bool = false
var _trail: CPUParticles3D

func _ready() -> void:
	_build_mesh()
	_build_trail()

func launch(velocity: Vector3) -> void:
	_velocity = velocity
	_flying = true
	_trail.emitting = true
	if _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)

func _process(delta: float) -> void:
	if not _flying:
		return
	var prev := global_position
	_velocity.y -= gravity * delta
	_velocity += Wind.accel() * delta        # dynamic wind drift
	global_position += _velocity * delta
	if _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)

	if _check_targets(prev):
		return

	# Landed short (or long): stick in the ground, scoring a miss.
	if global_position.y <= 0.03 and _velocity.y < 0.0:
		_stick(0, Color(0.55, 0.50, 0.35), STICK_SECONDS * 0.5)
		return

	# Despawn once it truly leaves the play area.
	if global_position.y < -5.0 or global_position.length() > 300.0:
		_finish(0)
		queue_free()

# Targets are flat faces on fixed z-planes (facing +Z, arrows travel -Z), so a
# hit is "crossed the face's plane inside a ring this frame" — the impact point
# is interpolated on the plane, which is what lets the arrow stick exactly where
# it visually lands.
func _check_targets(prev: Vector3) -> bool:
	for target in get_tree().get_nodes_in_group("targets"):
		var tz: float = target.global_position.z
		if not (prev.z > tz and global_position.z <= tz):
			continue
		var f := (prev.z - tz) / maxf(prev.z - global_position.z, 0.0001)
		var impact := prev.lerp(global_position, f)
		var lateral := impact.distance_to(target.global_position)
		if lateral <= target.hit_radius():
			global_position = impact
			var score: int = target.register_hit(impact)
			var off: Vector3 = (impact - target.global_position) / target.hit_radius()
			_stick(score, Target.ring_color(score), STICK_SECONDS, Vector2(off.x, off.y))
			return true
		elif lateral <= target.hit_radius() * 1.18:
			# Thunked into the straw boss just outside the rings: no score,
			# but the arrow stays there — great "so close" feedback.
			global_position = impact
			_stick(0, Color(0.80, 0.70, 0.46), STICK_SECONDS * 0.5)
			return true
	return false

## End the flight embedded at the current point, leave the arrow standing there
## for a while, and pop an impact burst in the given colour. The arrow's origin
## backs off along its flight line so only the head (EMBED_DEPTH) is buried —
## the shaft and fletching stay visible.
func _stick(score: int, burst_color: Color, linger: float, offset: Vector2 = Vector2.ZERO) -> void:
	_trail.emitting = false
	_spawn_burst(burst_color)
	global_position -= _velocity.normalized() * (0.6 - EMBED_DEPTH)
	_finish(score, offset)
	get_tree().create_timer(linger).timeout.connect(queue_free)

func _finish(score: int, offset: Vector2 = Vector2.ZERO) -> void:
	if _resolved:
		return
	_resolved = true
	_flying = false
	resolved.emit(score, offset)

# --- presentation ---------------------------------------------------------------

func _build_trail() -> void:
	_trail = CPUParticles3D.new()
	_trail.emitting = false
	_trail.amount = 50
	_trail.lifetime = 0.35
	_trail.local_coords = false          # particles hang in the air behind the arrow
	_trail.gravity = Vector3.ZERO
	var puff := SphereMesh.new()
	puff.radius = 0.025
	puff.height = 0.05
	puff.radial_segments = 6
	puff.rings = 3
	_trail.mesh = puff
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.9, 0.55))
	ramp.set_color(1, Color(1.0, 1.0, 0.9, 0.0))
	_trail.color_ramp = ramp
	_trail.material_override = _particle_material()
	add_child(_trail)

func _spawn_burst(color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 26
	burst.lifetime = 0.5
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.gravity = Vector3(0, -6, 0)
	var chip := BoxMesh.new()
	chip.size = Vector3(0.05, 0.05, 0.05)
	burst.mesh = chip
	burst.color = color
	burst.material_override = _particle_material()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func _particle_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _build_mesh() -> void:
	build_visual(self, 1.0)

## THE arrow look, shared by every arrow in the game — the one in flight and
## the one nocked on the bowstring are built by this same function, so what you
## shoot is exactly what you see land. Points along local -Z; `length` scales
## every part proportionally.
static func build_visual(root: Node3D, length: float = 1.0) -> void:
	var k := length
	# Shaft, long along local -Z (the flight direction).
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05 * k, 0.05 * k, length)
	shaft.mesh = box
	shaft.material_override = _flat_material(Color(0.95, 0.88, 0.65))
	root.add_child(shaft)

	# Red arrowhead (cone) at the front so the arrow is easy to track in flight.
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.08 * k
	cone.height = 0.22 * k
	head.mesh = cone
	head.material_override = _flat_material(Color(0.85, 0.20, 0.20))
	head.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)   # cone tip -> -Z
	head.position = Vector3(0.0, 0.0, -0.6 * k)
	root.add_child(head)

	# Three fletchings at the tail.
	for i in 3:
		var fin := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.012 * k, 0.13 * k, 0.18 * k)
		fin.mesh = fb
		fin.material_override = _flat_material(Color(0.90, 0.30, 0.20))
		fin.position = Vector3(0.0, 0.0, 0.42 * k)
		fin.rotation = Vector3(0.0, 0.0, deg_to_rad(120.0 * i))
		root.add_child(fin)

static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
