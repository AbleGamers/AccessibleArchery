extends Node3D
class_name Target
## A 3D scoring target — a full 10-ring World Archery face (gold/red/blue/black/
## white) on a straw boss with an A-frame stand, all built in code (no assets).
## Scoring is Olympic: 1–10 points by ring, 10 innermost. The hittable size
## scales with AssistSettings.target_size_scale, so difficulty can be tuned per
## player without touching gameplay code.

signal hit(score: int, at: Vector3)

@export var base_radius: float = 1.2

func _ready() -> void:
	add_to_group("targets")
	AssistSettings.changed.connect(_rebuild)
	_rebuild()

func hit_radius() -> float:
	return base_radius * AssistSettings.target_size_scale

## Olympic ring score for an impact point: 10 bands of equal width, innermost
## scores 10. The caller guarantees `at` is within hit_radius().
func register_hit(at: Vector3) -> int:
	var d := global_position.distance_to(at)
	var band := hit_radius() / 10.0
	var score := clampi(10 - int(d / band), 1, 10)
	hit.emit(score, at)
	return score

## World Archery face colour for a ring score (used by the face itself and by
## impact feedback like particle bursts and callouts).
static func ring_color(score: int) -> Color:
	if score >= 9:
		return Color(0.99, 0.83, 0.25)   # gold
	if score >= 7:
		return Color(0.84, 0.15, 0.16)   # red
	if score >= 5:
		return Color(0.05, 0.53, 0.74)   # blue
	if score >= 3:
		return Color(0.13, 0.13, 0.15)   # black
	return Color(0.94, 0.94, 0.90)       # white

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var r := hit_radius()

	# Straw boss behind the face, with a slightly darker rim ring.
	_disc(r * 1.18, 0.16, Vector3(0.0, 0.0, -0.10), Color(0.80, 0.70, 0.46), true)
	_disc(r * 1.22, 0.06, Vector3(0.0, 0.0, -0.16), Color(0.55, 0.46, 0.28), true)

	# The 10 rings, outermost (score 1) first, each scoring band a shade of its
	# WA colour pair — the outer ring of each pair slightly darker so the band
	# boundaries read at a distance.
	for score in range(1, 11):
		var radius := r * float(11 - score) / 10.0
		var col := ring_color(score)
		if score % 2 == 1:
			col = col.darkened(0.10)
		_disc(radius, 0.02, Vector3(0.0, 0.0, 0.004 * score), col, false)

	_build_stand(r)

# Flat cylinder facing the archer (+Z).
func _disc(radius: float, thickness: float, pos: Vector3, color: Color, shaded: bool) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = thickness
	mi.mesh = cyl
	# Cylinder axis is Y; rotate so the flat faces point along Z, toward the archer.
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if not shaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

# Wooden A-frame legs from behind the boss down to the ground, wherever this
# target happens to float (targets sit at varying heights).
func _build_stand(r: float) -> void:
	var ground_y := -global_position.y
	var wood := Color(0.42, 0.30, 0.17)
	for side in [-1.0, 1.0]:
		var top := Vector3(side * r * 0.35, r * 0.1, -0.14)
		var foot := Vector3(side * (r * 0.7 + 0.35), ground_y, -0.75)
		add_child(_leg(top, foot, 0.05, wood))
	# Cross brace between the legs.
	add_child(_leg(Vector3(-r * 0.5, ground_y * 0.45, -0.42), Vector3(r * 0.5, ground_y * 0.45, -0.42), 0.035, wood))

func _leg(a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.radial_segments = 6
	cyl.height = maxf((b - a).length(), 0.001)
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	var y := (b - a).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	return mi
