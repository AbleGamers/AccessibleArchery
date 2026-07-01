extends Node3D
class_name Target
## A 3D scoring target — concentric rings facing the archer. Its hittable size
## scales with AssistSettings.target_size_scale, so difficulty can be tuned per
## player without touching gameplay code. Rings are built in code (no assets).

signal hit(score: int, at: Vector3)

@export var base_radius: float = 1.2

func _ready() -> void:
	add_to_group("targets")
	AssistSettings.changed.connect(_rebuild)
	_rebuild()

func hit_radius() -> float:
	return base_radius * AssistSettings.target_size_scale

func register_hit(at: Vector3) -> int:
	var d := global_position.distance_to(at)
	var r := hit_radius()
	var score := 1
	if d <= r * 0.2:
		score = 10
	elif d <= r * 0.5:
		score = 5
	hit.emit(score, at)
	return score

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var r := hit_radius()
	_ring(r, Color(0.92, 0.92, 0.92), 0.00)
	_ring(r * 0.6, Color(0.23, 0.40, 1.0), 0.01)
	_ring(r * 0.25, Color(1.0, 0.84, 0.10), 0.02)

func _ring(radius: float, color: Color, z: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	mi.mesh = cyl
	# Cylinder axis is Y; rotate so the flat circular faces point along Z,
	# toward the archer.
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	mi.position = Vector3(0.0, 0.0, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
