extends Node3D
class_name MeadowRange
## Low-poly outdoor tournament meadow built entirely in code — the "festival
## field" replacement for the Olympic arena (same contract, different venue):
## rolling grass, a tree line and distant hills, festival tents and flag-lined
## lanes, hay bales + small bleachers for the crowd, an earth berm backstop
## behind the targets, and a scaffold-mounted LED screen that carries the live
## match state (set_jumbotron, same API as Stadium). No art assets — swap for
## authored scenes later.
##
## The shooting lane runs down -Z (archer at +Z, targets toward -Z).
##
## Accessibility notes: everything here is static — no swaying trees, flapping
## flags, or animated water — so the Low-motion preset stays honest. The berm
## behind the targets is a plain, quiet earth tone so the reticle and target
## faces read against it.

const CANVAS_RED := Color(0.78, 0.16, 0.16)
const CANVAS_WHITE := Color(0.92, 0.93, 0.96)
const CANVAS_BLUE := Color(0.14, 0.24, 0.70)
const CANVAS_YELLOW := Color(0.93, 0.76, 0.14)
const GRASS := Color(0.32, 0.47, 0.24)
const EARTH := Color(0.42, 0.33, 0.22)
const WOOD := Color(0.52, 0.40, 0.26)
const STEEL := Color(0.58, 0.61, 0.66)
const HAY := Color(0.82, 0.70, 0.38)

var _crowd_xforms: Array[Transform3D] = []
var _crowd_colors: Array[Color] = []

## 0.0 = bright midday, 1.0 = golden-hour dusk. Rolled once per launch (the
## GDD's "dynamic time of day": every match looks fresh). The meadow layout
## itself stays seeded so the venue is stable.
var _tod: float = 0.0

var _screen_viewport: SubViewport
var _screen_title: Label
var _screen_body: Label

func _ready() -> void:
	randomize()
	_tod = randf()
	seed(20260716)
	_build_sky_and_sun()
	_build_field()
	_build_berm()
	_build_screen()
	_build_flag_line(-5.5)
	_build_flag_line(5.5)
	_build_tents(-21.0)
	_build_tents(21.0)
	_build_bleacher(Vector3(-11.5, 0.0, -17.0))
	_build_bleacher(Vector3(11.5, 0.0, -17.0))
	_build_hay_bales()
	_commit_crowd()
	_build_tree_line()
	_build_hills()
	_build_light_rig(Vector3(-8.5, 0.0, -30.0))
	_build_light_rig(Vector3(8.5, 0.0, -30.0))

# --- sky + light --------------------------------------------------------------

# Everything lerps between a bright midday look (_tod = 0) and a warm
# golden-hour look (_tod = 1): sun height, sun colour, and sky palette.
func _build_sky_and_sun() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.55, 0.90).lerp(Color(0.24, 0.38, 0.66), _tod)
	sky_mat.sky_horizon_color = Color(0.76, 0.87, 0.96).lerp(Color(0.98, 0.72, 0.46), _tod)
	sky_mat.ground_horizon_color = Color(0.68, 0.80, 0.72).lerp(Color(0.88, 0.64, 0.44), _tod)
	sky_mat.ground_bottom_color = Color(0.28, 0.38, 0.24).lerp(Color(0.24, 0.28, 0.22), _tod)
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
	sun.rotation_degrees = Vector3(lerpf(-56.0, -14.0, _tod), lerpf(-35.0, -55.0, _tod), 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94).lerp(Color(1.0, 0.82, 0.62), _tod)
	sun.light_energy = lerpf(1.3, 1.05, _tod)
	add_child(sun)

# --- field --------------------------------------------------------------------

func _build_field() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 300.0)
	ground.mesh = plane
	ground.material_override = _mat(GRASS)
	ground.position = Vector3(0.0, 0.0, -20.0)
	add_child(ground)

	# Mown competition strip down the shooting axis (echoes the GDD floor
	# markings) — a lighter cut of grass instead of the arena's painted lane.
	var lane := MeshInstance3D.new()
	var lane_plane := PlaneMesh.new()
	lane_plane.size = Vector2(9.0, 46.0)
	lane.mesh = lane_plane
	lane.material_override = _mat(Color(0.44, 0.58, 0.32))
	lane.position = Vector3(0.0, 0.02, -10.0)
	add_child(lane)
	_line(CANVAS_RED, -2.0)
	_line(CANVAS_WHITE, 0.0)
	_line(CANVAS_YELLOW, 2.0)

func _line(color: Color, x: float) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.03, 46.0)
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = Vector3(x, 0.04, -10.0)
	add_child(mi)

# --- berm backstop --------------------------------------------------------------

# A plain earth mound behind the targets replaces the arena's concrete back
# wall: same safety fiction, and a deliberately quiet, high-contrast backdrop
# for the target faces and reticle.
func _build_berm() -> void:
	var berm := MeshInstance3D.new()
	var mound := CapsuleMesh.new()
	mound.radius = 3.2
	mound.height = 50.0
	berm.mesh = mound
	berm.material_override = _mat(EARTH)
	berm.rotation_degrees = Vector3(0.0, 0.0, 90.0)   # lay the capsule on its side
	berm.position = Vector3(0.0, 0.8, -34.0)
	berm.scale = Vector3(1.0, 1.0, 0.55)              # squash front-to-back
	add_child(berm)

	# A grass crown so the mound reads as turfed earth, not a pipe.
	var crown := MeshInstance3D.new()
	var top := CapsuleMesh.new()
	top.radius = 2.6
	top.height = 48.0
	crown.mesh = top
	crown.material_override = _mat(GRASS * 0.9)
	crown.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	crown.position = Vector3(0.0, 2.0, -34.6)
	crown.scale = Vector3(1.0, 1.0, 0.55)
	add_child(crown)

# --- LED screen ----------------------------------------------------------------

# Festival LED screen on a scaffold above the berm — a LIVE display: a
# SubViewport renders the match state and is textured (albedo + emission, so
# it glows like an LED wall) onto the screen face. main.gd feeds it via
# set_jumbotron(), exactly as it fed the arena's jumbotron.
func _build_screen() -> void:
	for side in [-1.0, 1.0]:
		add_child(_segment(Vector3(side * 4.4, 0.0, -32.6), Vector3(side * 4.4, 7.0, -32.6), 0.14, STEEL))
		add_child(_segment(Vector3(side * 4.4, 3.5, -32.6), Vector3(side * 3.0, 5.6, -32.6), 0.07, STEEL))

	var screen := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(8.0, 4.5, 0.4)
	screen.mesh = sbox
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.05, 0.07, 0.10)
	screen.material_override = smat
	screen.position = Vector3(0.0, 7.5, -32.6)
	add_child(screen)
	_build_screen_face()

func _build_screen_face() -> void:
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

## Push live match text onto the venue's big screen (same API as Stadium).
func set_jumbotron(title: String, body: String) -> void:
	if _screen_title != null:
		_screen_title.text = title
	if _screen_body != null:
		_screen_body.text = body

# --- flag-lined lane ------------------------------------------------------------

# Tournament flags stake out the lane. Static by design (no flapping) so the
# Low-motion preset holds; the wind is still captioned + heard, never shown as
# screen motion.
func _build_flag_line(x: float) -> void:
	var cols := [CANVAS_RED, CANVAS_WHITE, CANVAS_BLUE, CANVAS_YELLOW]
	var i := 0
	var z := -2.0
	while z >= -28.0:
		add_child(_segment(Vector3(x, 0.0, z), Vector3(x, 3.2, z), 0.05, WOOD))
		var flag := MeshInstance3D.new()
		var fbox := BoxMesh.new()
		fbox.size = Vector3(0.06, 0.7, 1.0)
		flag.mesh = fbox
		flag.material_override = _mat(cols[i % cols.size()])
		flag.position = Vector3(x + (0.06 if x > 0.0 else -0.06), 2.7, z - 0.55)
		add_child(flag)
		i += 1
		z -= 6.5

# --- festival tents ---------------------------------------------------------------

func _build_tents(x: float) -> void:
	var cols := [CANVAS_RED, CANVAS_BLUE, CANVAS_YELLOW]
	for i in 3:
		var z := -4.0 - i * 10.0
		var base := Vector3(x, 0.0, z)
		# Four corner posts and a canvas cone roof.
		for c in [Vector3(2.2, 0, 2.2), Vector3(-2.2, 0, 2.2), Vector3(2.2, 0, -2.2), Vector3(-2.2, 0, -2.2)]:
			add_child(_segment(base + c, base + c + Vector3(0, 2.6, 0), 0.09, WOOD))
		var roof := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.4
		cone.height = 2.0
		cone.radial_segments = 8
		roof.mesh = cone
		roof.material_override = _mat(cols[i])
		roof.position = base + Vector3(0.0, 3.6, 0.0)
		add_child(roof)
		# Counter table facing the lane.
		var table := MeshInstance3D.new()
		var tbox := BoxMesh.new()
		tbox.size = Vector3(0.7, 0.9, 3.6)
		table.mesh = tbox
		table.material_override = _mat(WOOD * 1.1)
		table.position = base + Vector3(-2.0 if x > 0.0 else 2.0, 0.45, 0.0)
		add_child(table)

# --- bleachers + hay bales + crowd ------------------------------------------------

# A small four-tier grandstand set back down the lane on each flank, angled to
# face the shooting line (same MultiMesh crowd the arena had). Tiers step out in
# their own deep steps so the stand reads as raked seating, not a solid wall of
# cubes when the over-the-shoulder camera catches the near flank.
func _build_bleacher(center: Vector3) -> void:
	var outward := Vector3(1, 0, 0) if center.x > 0.0 else Vector3(-1, 0, 0)
	var length := 15.0
	var step_out := 1.35
	var step_up := 0.75
	# Skid legs under the stand so it sits on the grass like a real bleacher.
	for lz in [-length * 0.5 + 0.5, 0.0, length * 0.5 - 0.5]:
		var foot := center + Vector3(0.0, 0.0, lz)
		add_child(_segment(foot, foot + outward * (step_out * 3.5) + Vector3.UP * (step_up * 3.5), 0.12, STEEL))
	for i in 4:
		var base := center + outward * (i * step_out) + Vector3.UP * (i * step_up)
		# A bench plank (thin, seat-deep) rather than a full-height block — the gap
		# between tiers is what stops it looking like stacked crates.
		_solid(_box(Vector3(step_out * 0.9, 0.22, length)), base + Vector3.UP * 0.11, WOOD * (0.92 + 0.05 * (i % 2)))
		var seat_top := base + Vector3.UP * 0.5
		var seats := int(length / 1.25)
		for j in seats:
			var p := seat_top + Vector3(0, 0, -length * 0.5 + 0.6 + j * 1.25)
			p += outward * randf_range(-0.1, 0.1)
			_crowd_xforms.append(Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.85, 1.1)), p))
			_crowd_colors.append([CANVAS_RED, CANVAS_WHITE, CANVAS_BLUE, CANVAS_YELLOW][randi() % 4])

# Hay bales dotted along the lane ropes — extra festival seating.
func _build_hay_bales() -> void:
	for side in [-1.0, 1.0]:
		var z := -6.0
		while z >= -26.0:
			var bale := MeshInstance3D.new()
			var bbox := BoxMesh.new()
			bbox.size = Vector3(1.4, 0.8, 0.9)
			bale.mesh = bbox
			bale.material_override = _mat(HAY)
			bale.position = Vector3(side * 7.6, 0.4, z + randf_range(-0.6, 0.6))
			bale.rotation_degrees = Vector3(0.0, randf_range(-14.0, 14.0), 0.0)
			add_child(bale)
			# Roughly half the bales have a spectator perched on them.
			if randf() < 0.55:
				var p := bale.position + Vector3(0.0, 0.75, 0.0)
				_crowd_xforms.append(Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.85, 1.1)), p))
				_crowd_colors.append([CANVAS_RED, CANVAS_WHITE, CANVAS_BLUE, CANVAS_YELLOW][randi() % 4])
			z -= 4.5

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

# --- tree line + hills ------------------------------------------------------------

# A seeded ring of low-poly trees around the field. The corridor behind the
# berm is kept clear so the backdrop above the targets stays quiet sky.
func _build_tree_line() -> void:
	for i in 34:
		var a := TAU * float(i) / 34.0 + randf_range(-0.06, 0.06)
		var r := randf_range(52.0, 78.0)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r - 20.0)
		if absf(p.x) < 22.0 and p.z < -28.0:
			continue   # keep the sightline over the berm clean
		_build_tree(p)

func _build_tree(base: Vector3) -> void:
	var h := randf_range(4.5, 7.5)
	add_child(_segment(base, base + Vector3(0, h * 0.45, 0), 0.28, WOOD * 0.8))
	var canopy := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = h * 0.32
	blob.height = h * 0.75
	blob.radial_segments = 8
	blob.rings = 4
	canopy.mesh = blob
	canopy.material_override = _mat(Color(0.22, 0.40, 0.20) * randf_range(0.85, 1.15))
	canopy.position = base + Vector3(0.0, h * 0.65, 0.0)
	add_child(canopy)

# Distant rolling hills — big domes ringing the far horizon. Sized and raised so
# their crowns clear the tree line (and the berm, straight down the lane), so the
# meadow reads as open country rather than a flat green disc. A hazy blue-green
# tint sells the aerial-perspective distance.
func _build_hills() -> void:
	for i in 9:
		var a := PI + PI * float(i) / 8.0   # arc across the far half of the horizon
		var p := Vector3(cos(a) * 150.0, -2.0, sin(a) * 150.0 - 40.0)
		var hill := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = randf_range(40.0, 66.0)
		dome.height = randf_range(34.0, 52.0)
		dome.radial_segments = 12
		dome.rings = 6
		hill.mesh = dome
		# Fade toward the sky's horizon colour with the time of day, so the ridge
		# line settles into the haze instead of standing out as hard geometry.
		var base_col := Color(0.34, 0.46, 0.40).lerp(Color(0.52, 0.44, 0.42), _tod)
		hill.material_override = _mat(base_col * randf_range(0.92, 1.06))
		hill.position = p
		add_child(hill)

# --- festival light rig ------------------------------------------------------------

# A modest pole-mounted light panel each side of the berm — the meadow's answer
# to the arena floodlights. The lamps come alive as the day fades.
func _build_light_rig(base: Vector3) -> void:
	add_child(_segment(base, base + Vector3(0, 6.5, 0), 0.12, STEEL))
	var panel := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(2.4, 1.2, 0.4)
	panel.mesh = pbox
	panel.material_override = _mat(STEEL * 0.8)
	panel.position = base + Vector3(0.0, 6.9, 0.0)
	panel.look_at_from_position(panel.position, Vector3(0.0, 2.0, -14.0), Vector3.UP)
	add_child(panel)
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	var lbox := BoxMesh.new()
	lbox.size = Vector3(0.5, 0.5, 0.16)
	lamps.mesh = lbox
	lamps.instance_count = 4
	for lx in 4:
		lamps.set_instance_transform(lx, Transform3D(Basis(), Vector3(-0.85 + lx * 0.57, 0.0, 0.26)))
	var lmmi := MultiMeshInstance3D.new()
	lmmi.multimesh = lamps
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.97, 0.85)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.96, 0.82)
	# Barely-on at midday, glowing at golden hour.
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
