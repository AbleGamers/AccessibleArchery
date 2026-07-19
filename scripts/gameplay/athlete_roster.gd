extends RefCounted
class_name AthleteRoster
## The playable roster (GDD: "four distinct, stylized athletes … inclusive
## representation — including wheelchair-using athletes — first-class
## throughout"). Every athlete is built in code from the same low-poly kit —
## no art assets — and every athlete plays through the exact same intent
## pipeline; seated vs standing changes only the model and the shooting height,
## never the aim envelope.
##
## Coordinates are relative to the SHOULDER (the ArcheryController's origin):
## the body hangs below, the head sits above, the aim arms live on the pitch
## pivot. `eye_height()` tells the range where that origin belongs.

const ATHLETES := [
	{
		"name": "MAYA", "tagline": "Standing · Recurve",
		"skin": Color(0.45, 0.30, 0.20), "kit": Color(0.55, 0.24, 0.78),
		"trim": Color(1.00, 0.84, 0.24), "hair": Color(0.08, 0.07, 0.06),
		"hair_style": "ponytail", "seated": false,
	},
	{
		"name": "LEO", "tagline": "Standing · Composite",
		"skin": Color(0.86, 0.67, 0.52), "kit": Color(0.90, 0.19, 0.26),
		"trim": Color(0.97, 0.97, 0.97), "hair": Color(0.35, 0.22, 0.10),
		"hair_style": "short", "seated": false,
	},
	{
		"name": "ANA", "tagline": "Wheelchair · Recurve",
		"skin": Color(0.70, 0.50, 0.35), "kit": Color(0.09, 0.68, 0.64),
		"trim": Color(1.00, 0.47, 0.34), "hair": Color(0.12, 0.10, 0.09),
		"hair_style": "bun", "seated": true,
	},
	{
		"name": "KAI", "tagline": "Wheelchair · Composite",
		"skin": Color(0.96, 0.80, 0.65), "kit": Color(0.14, 0.42, 0.93),
		"trim": Color(1.00, 0.58, 0.12), "hair": Color(0.05, 0.05, 0.06),
		"hair_style": "short", "seated": true,
	},
]

const STANDING_EYE := 1.6
const SEATED_EYE := 1.15
const DARK := Color(0.16, 0.19, 0.24)

static func get_def(index: int) -> Dictionary:
	return ATHLETES[clampi(index, 0, ATHLETES.size() - 1)]

## Shoulder/arrow height above the ground for the selected athlete.
static func eye_height(index: int) -> float:
	return SEATED_EYE if get_def(index).get("seated", false) else STANDING_EYE

## The body (everything that does NOT rise with aim): head, torso, legs or
## wheelchair, quiver. Faces -Z, the shooting direction. Returns refs to the
## nodes the controller animates during the draw ("head": the head+hair pivot).
static func build_body(parent: Node3D, def: Dictionary) -> Dictionary:
	var skin: Color = def["skin"]
	var kit: Color = def["kit"]
	var trim: Color = def["trim"]

	# Head + hair on a pivot at the neck, so the head can tilt during the draw.
	var head_pivot := Node3D.new()
	head_pivot.position = Vector3(0.0, 0.18, 0.02)
	parent.add_child(head_pivot)
	var head := SphereMesh.new()
	head.radius = 0.12
	head.height = 0.24
	_solid(head_pivot, head, Vector3(0.0, 0.12, 0.0), skin)
	_build_hair(head_pivot, def)

	# Torso in team kit, with a trim stripe across the chest.
	var torso := BoxMesh.new()
	torso.size = Vector3(0.42, 0.60, 0.24)
	_solid(parent, torso, Vector3(0.0, -0.16, 0.0), kit)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.43, 0.09, 0.25)
	_solid(parent, stripe, Vector3(0.0, -0.04, 0.0), trim)

	# Quiver on the back with a couple of spare shafts poking out.
	var quiver := _solid(parent, _box(0.09, 0.46, 0.09), Vector3(0.19, -0.14, 0.15), trim)
	quiver.rotation_degrees = Vector3(0.0, 0.0, -16.0)
	for i in 2:
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.012
		shaft.bottom_radius = 0.012
		shaft.height = 0.30
		var s := _solid(parent, shaft, Vector3(0.23 + 0.03 * i, 0.12, 0.15), Color(0.95, 0.88, 0.65))
		s.rotation_degrees = Vector3(0.0, 0.0, -16.0)

	if def.get("seated", false):
		_build_seated_lower(parent, def)
	else:
		_build_standing_lower(parent, def)
	return {"head": head_pivot}

static func _build_standing_lower(parent: Node3D, _def: Dictionary) -> void:
	_solid(parent, _box(0.40, 0.18, 0.24), Vector3(0.0, -0.56, 0.0), DARK)   # hips
	for side in [-1.0, 1.0]:
		_solid(parent, _box(0.16, 0.86, 0.18), Vector3(0.11 * side, -1.10, 0.0), DARK)
		_solid(parent, _box(0.15, 0.09, 0.30), Vector3(0.11 * side, -1.56, -0.04), Color(0.10, 0.10, 0.12))

## Seated athlete in a sports wheelchair. Ground is at -SEATED_EYE locally.
static func _build_seated_lower(parent: Node3D, def: Dictionary) -> void:
	var kit: Color = def["kit"]
	var skin_ground := -SEATED_EYE
	var frame := Color(0.55, 0.58, 0.63)
	var tire := Color(0.10, 0.10, 0.12)

	_solid(parent, _box(0.40, 0.16, 0.24), Vector3(0.0, -0.50, 0.0), DARK)          # hips
	_solid(parent, _box(0.50, 0.06, 0.46), Vector3(0.0, -0.60, -0.06), frame)       # seat
	_solid(parent, _box(0.46, 0.32, 0.06), Vector3(0.0, -0.40, 0.24), frame)        # backrest
	for side in [-1.0, 1.0]:
		_solid(parent, _box(0.15, 0.14, 0.42), Vector3(0.11 * side, -0.60, -0.20), DARK)    # thigh
		_solid(parent, _box(0.14, 0.38, 0.14), Vector3(0.11 * side, -0.84, -0.38), DARK)    # shin
		_solid(parent, _box(0.13, 0.08, 0.24), Vector3(0.11 * side, -1.04, -0.42), tire)    # shoe
	_solid(parent, _box(0.42, 0.04, 0.12), Vector3(0.0, -1.09, -0.42), frame)       # footrest

	# Big cambered main wheels: tire + kit-coloured handrim + hub.
	var axle_y := skin_ground + 0.34
	for side in [-1.0, 1.0]:
		var tire_mesh := CylinderMesh.new()
		tire_mesh.top_radius = 0.34
		tire_mesh.bottom_radius = 0.34
		tire_mesh.height = 0.045
		var w := _solid(parent, tire_mesh, Vector3(0.31 * side, axle_y, 0.10), tire)
		w.rotation_degrees = Vector3(0.0, 0.0, 90.0 - 8.0 * side)   # slight camber
		var rim := CylinderMesh.new()
		rim.top_radius = 0.27
		rim.bottom_radius = 0.27
		rim.height = 0.055
		var r := _solid(parent, rim, Vector3(0.31 * side, axle_y, 0.10), kit)
		r.rotation_degrees = Vector3(0.0, 0.0, 90.0 - 8.0 * side)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.07
		hub.bottom_radius = 0.07
		hub.height = 0.07
		var h := _solid(parent, hub, Vector3(0.31 * side, axle_y, 0.10), frame)
		h.rotation_degrees = Vector3(0.0, 0.0, 90.0 - 8.0 * side)
	# Small front casters.
	for side in [-1.0, 1.0]:
		var caster := CylinderMesh.new()
		caster.top_radius = 0.08
		caster.bottom_radius = 0.08
		caster.height = 0.04
		var c := _solid(parent, caster, Vector3(0.20 * side, skin_ground + 0.08, -0.34), tire)
		c.rotation_degrees = Vector3(0.0, 0.0, 90.0)

## The aim arms (they rise and fall with the pitch pivot): bow arm reaching
## forward to the grip, draw arm on the string, skin-tone hands. Returns refs
## so the controller can animate the draw arm pulling the string back
## ("draw_arm": the arm segment, "draw_hand": the string hand).
static func build_arms(pivot: Node3D, def: Dictionary) -> Dictionary:
	var kit: Color = def["kit"]
	var skin: Color = def["skin"]
	pivot.add_child(_segment(Vector3(-0.20, 0.0, 0.0), Vector3(-0.06, 0.0, -0.55), 0.05, kit))
	var draw_arm := _segment(Vector3(0.20, -0.02, 0.05), Vector3(0.0, 0.0, -0.58), 0.05, kit)
	pivot.add_child(draw_arm)
	var hand := SphereMesh.new()
	hand.radius = 0.05
	hand.height = 0.10
	_solid(pivot, hand, Vector3(-0.06, 0.0, -0.55), skin)
	var hand2 := SphereMesh.new()
	hand2.radius = 0.05
	hand2.height = 0.10
	var draw_hand := _solid(pivot, hand2, Vector3(0.0, 0.0, -0.58), skin)
	return {"draw_arm": draw_arm, "draw_hand": draw_hand}

# Coordinates are local to the head pivot (which sits at the neck).
static func _build_hair(parent: Node3D, def: Dictionary) -> void:
	var hair: Color = def["hair"]
	var cap := SphereMesh.new()
	cap.radius = 0.125
	cap.height = 0.22
	_solid(parent, cap, Vector3(0.0, 0.16, 0.025), hair)
	match str(def.get("hair_style", "short")):
		"ponytail":
			var tail := _solid(parent, _box(0.06, 0.26, 0.06), Vector3(0.0, 0.04, 0.13), hair)
			tail.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
		"bun":
			var bun := SphereMesh.new()
			bun.radius = 0.06
			bun.height = 0.12
			_solid(parent, bun, Vector3(0.0, 0.22, 0.09), hair)
		_:
			pass   # "short" is just the cap

# --- helpers --------------------------------------------------------------------

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _solid(parent: Node, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _segment(a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.radial_segments = 8
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
