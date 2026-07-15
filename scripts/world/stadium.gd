extends Node3D
class_name Stadium
## Low-poly Olympic arena built entirely in code (concept art, image 1): sunset
## sky, a field with lane lines, raked grandstands packed with a MultiMesh crowd,
## a big back arch, two floodlight towers, a jumbotron flanked by banners, and a
## back wall behind the targets. No art assets — swap for authored scenes later.
##
## The shooting lane runs down -Z (archer at +Z, targets toward -Z), so the bowl
## is laid out around that axis.

const CONCRETE := Color(0.72, 0.72, 0.75)
const STEEL := Color(0.58, 0.61, 0.66)
const RED := Color(0.78, 0.16, 0.16)
const WHITE := Color(0.92, 0.93, 0.96)
const BLUE := Color(0.14, 0.24, 0.70)

var _crowd_xforms: Array[Transform3D] = []
var _crowd_colors: Array[Color] = []

## 0.0 = bright midday, 1.0 = dramatic dusk. Rolled once per launch (the GDD's
## "dynamic time of day": every match looks fresh). The crowd/stand layout stays
## seeded so the arena itself is stable.
var _tod: float = 0.0

var _screen_viewport: SubViewport
var _screen_title: Label
var _screen_body: Label

func _ready() -> void:
	randomize()
	_tod = randf()
	seed(20240630)
	_build_sky_and_sun()
	_build_field()
	_build_stand(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -15), 52.0, 11, 11.0)   # left
	_build_stand(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -15), 52.0, 11, 11.0)  # right
	_build_stand(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 14), 48.0, 11, 11.0)    # behind archer
	_commit_crowd()
	_build_back_wall_and_banners()
	_build_arch(Vector3(0, 0, -34), 17.0)
	_build_floodlight(Vector3(-26, 0, -24), 22.0, STEEL)
	_build_floodlight(Vector3(26, 0, -24), 22.0, RED)

# --- sky + light --------------------------------------------------------------

# Everything lerps between a bright midday look (_tod = 0) and the warm sunset
# look (_tod = 1): sun height, sun colour, and sky palette.
func _build_sky_and_sun() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.52, 0.88).lerp(Color(0.20, 0.40, 0.72), _tod)
	sky_mat.sky_horizon_color = Color(0.74, 0.85, 0.96).lerp(Color(0.97, 0.66, 0.42), _tod)
	sky_mat.ground_horizon_color = Color(0.70, 0.78, 0.82).lerp(Color(0.90, 0.62, 0.42), _tod)
	sky_mat.ground_bottom_color = Color(0.26, 0.32, 0.28).lerp(Color(0.22, 0.26, 0.24), _tod)
	sky_mat.sun_angle_max = lerpf(6.0, 12.0, _tod)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = lerpf(1.05, 0.9, _tod)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(lerpf(-56.0, -16.0, _tod), lerpf(-35.0, -50.0, _tod), 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94).lerp(Color(1.0, 0.84, 0.68), _tod)
	sun.light_energy = lerpf(1.3, 1.1, _tod)
	add_child(sun)

# --- field --------------------------------------------------------------------

func _build_field() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 260.0)
	ground.mesh = plane
	ground.material_override = _mat(Color(0.30, 0.45, 0.25))
	ground.position = Vector3(0.0, 0.0, -20.0)
	add_child(ground)

	# Range lane lines down the shooting axis (echoes the GDD floor markings).
	var lane := MeshInstance3D.new()
	var lane_plane := PlaneMesh.new()
	lane_plane.size = Vector2(9.0, 46.0)
	lane.mesh = lane_plane
	lane.material_override = _mat(Color(0.78, 0.80, 0.84))
	lane.position = Vector3(0.0, 0.02, -10.0)
	add_child(lane)
	_line(Color(0.80, 0.20, 0.20), -2.0)
	_line(Color(0.20, 0.35, 0.85), 0.0)
	_line(Color(0.95, 0.78, 0.10), 2.0)

func _line(color: Color, x: float) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.03, 46.0)
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = Vector3(x, 0.04, -10.0)
	add_child(mi)

# --- grandstands + crowd ------------------------------------------------------

func _build_stand(outward: Vector3, along: Vector3, center: Vector3, length: float, tiers: int, inner: float) -> void:
	var step_out := 1.9
	var step_up := 1.05
	for i in tiers:
		var base := center + outward * (inner + i * step_out) + Vector3.UP * (i * step_up)
		var size := (outward.abs() * step_out) + (along.abs() * length) + Vector3(0.0, step_up, 0.0)
		var shade := 0.78 + 0.02 * (i % 3)
		_solid(_box(size), base + Vector3.UP * (step_up * 0.5), CONCRETE * shade)
		# A row of spectators sitting on this tier.
		var seat_top := base + Vector3.UP * (step_up + 0.28) - outward * 0.4
		var seats := int(length / 1.25)
		for j in seats:
			var p := seat_top + along * (-length * 0.5 + 0.6 + j * 1.25)
			p += outward * randf_range(-0.15, 0.15)
			_crowd_xforms.append(Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.85, 1.1)), p))
			_crowd_colors.append([RED, WHITE, BLUE][randi() % 3])

func _commit_crowd() -> void:
	if _crowd_xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.7, 0.5)
	mm.mesh = box
	mm.instance_count = _crowd_xforms.size()
	for k in _crowd_xforms.size():
		mm.set_instance_transform(k, _crowd_xforms[k])
		mm.set_instance_color(k, _crowd_colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)

# --- back wall, jumbotron, banners --------------------------------------------

func _build_back_wall_and_banners() -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(46.0, 6.0, 0.6)
	wall.mesh = box
	wall.material_override = _mat(CONCRETE * 0.92)
	wall.position = Vector3(0.0, 3.0, -33.0)
	add_child(wall)

	# Jumbotron screen, centred — a LIVE display: a SubViewport renders the
	# match state and is textured (albedo + emission, so it glows like an LED
	# wall) onto the screen face. main.gd feeds it via set_jumbotron().
	var screen := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(8.0, 4.5, 0.4)
	screen.mesh = sbox
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.05, 0.07, 0.10)
	screen.material_override = smat
	screen.position = Vector3(0.0, 7.5, -32.6)
	add_child(screen)
	_build_jumbotron_face()

	# Vertical banners flanking the screen.
	var cols := [RED, WHITE, BLUE, RED, WHITE, BLUE]
	for i in cols.size():
		var side := -1.0 if i < 3 else 1.0
		var idx := i % 3
		var banner := MeshInstance3D.new()
		var bbox := BoxMesh.new()
		bbox.size = Vector3(1.3, 5.0, 0.2)
		banner.mesh = bbox
		banner.material_override = _mat(cols[i])
		banner.position = Vector3(side * (6.0 + idx * 1.6), 7.5, -32.5)
		add_child(banner)

# The live face of the jumbotron: a SubViewport renders two labels on a dark
# panel; the resulting texture is shown emissive (albedo + emission) on a quad
# just in front of the screen box, so it reads like an LED wall from anywhere
# in the arena.
func _build_jumbotron_face() -> void:
	_screen_viewport = SubViewport.new()
	_screen_viewport.size = Vector2i(512, 288)
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_screen_viewport)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_viewport.add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	_screen_viewport.add_child(vb)

	_screen_title = Label.new()
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_title.add_theme_font_size_override("font_size", 44)
	_screen_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25))
	_screen_title.text = "ARCHER'S ROUND"
	vb.add_child(_screen_title)

	_screen_body = Label.new()
	_screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_body.add_theme_font_size_override("font_size", 58)
	_screen_body.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_screen_body.text = "WELCOME"
	vb.add_child(_screen_body)

	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(7.6, 4.1)
	face.mesh = quad
	var mat := StandardMaterial3D.new()
	var tex := _screen_viewport.get_texture()
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 1.3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override = mat
	face.position = Vector3(0.0, 7.5, -32.38)   # just proud of the screen box
	add_child(face)

## Push live match text onto the stadium's big screen.
func set_jumbotron(title: String, body: String) -> void:
	if _screen_title != null:
		_screen_title.text = title
	if _screen_body != null:
		_screen_body.text = body

# --- big back arch ------------------------------------------------------------

func _build_arch(base: Vector3, radius: float) -> void:
	var segments := 12
	var prev := base + Vector3(radius, 0.0, 0.0)
	for i in range(1, segments + 1):
		var a := PI * float(i) / float(segments)
		var p := base + Vector3(cos(a) * radius, sin(a) * radius, 0.0)
		add_child(_segment(prev, p, 1.1, Color(0.85, 0.86, 0.89)))
		prev = p

# --- floodlight tower ---------------------------------------------------------

func _build_floodlight(base: Vector3, height: float, color: Color) -> void:
	var spread := 1.6
	var top := 0.5
	var corners := [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
	var tops: Array[Vector3] = []
	for c in corners:
		var b: Vector3 = base + Vector3(c.x * spread, 0.0, c.z * spread)
		var t: Vector3 = base + Vector3(c.x * top, height, c.z * top)
		add_child(_segment(b, t, 0.16, color))
		tops.append(t)
	# A few cross rungs up the tower.
	for f in range(1, 5):
		var y := height * float(f) / 5.0
		var ring: Array[Vector3] = []
		for c in corners:
			var lerp_t := y / height
			ring.append(base + Vector3(lerpf(c.x * spread, c.x * top, lerp_t), y, lerpf(c.z * spread, c.z * top, lerp_t)))
		add_child(_segment(ring[0], ring[1], 0.08, color))
		add_child(_segment(ring[1], ring[3], 0.08, color))
		add_child(_segment(ring[3], ring[2], 0.08, color))
		add_child(_segment(ring[2], ring[0], 0.08, color))

	# Light panel on top, facing the field, with glowing lamps.
	var panel := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(5.5, 2.6, 0.5)
	panel.mesh = pbox
	panel.material_override = _mat(color * 0.8)
	panel.position = base + Vector3(0.0, height + 1.3, 0.0)
	panel.look_at_from_position(panel.position, Vector3(0.0, 6.0, -14.0), Vector3.UP)
	add_child(panel)
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	var lbox := BoxMesh.new()
	lbox.size = Vector3(0.7, 0.7, 0.2)
	lamps.mesh = lbox
	lamps.instance_count = 12
	var n := 0
	for ly in 3:
		for lx in 4:
			lamps.set_instance_transform(n, Transform3D(Basis(), Vector3(-1.9 + lx * 1.25, -0.7 + ly * 0.7, 0.32)))
			n += 1
	var lmmi := MultiMeshInstance3D.new()
	lmmi.multimesh = lamps
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.97, 0.85)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.96, 0.82)
	# The lamps come alive as the day fades — barely-on at midday, blazing at dusk.
	lmat.emission_energy_multiplier = lerpf(0.4, 3.0, _tod)
	lmmi.material_override = lmat
	panel.add_child(lmmi)

# --- helpers ------------------------------------------------------------------

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _solid(mesh: Mesh, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)

func _segment(a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.radial_segments = 6
	cyl.height = maxf((b - a).length(), 0.001)
	mi.mesh = cyl
	mi.material_override = _mat(color)
	var y := (b - a).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	return mi
