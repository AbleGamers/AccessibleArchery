extends Node
class_name AttractMode
## Booth resilience: after a stretch with no input on ANY device, the game
## demos itself — it picks a random athlete, aims real shots at real targets
## (with a little human error) and keeps the arena alive under an
## "AUTO DEMO — touch any control to play" banner. The first real input wakes
## it instantly; main.gd then resets the match and reopens the athlete select,
## so the station is always fresh for the next player.
##
## Idle detection covers every path: raw events (keys, pads, mouse) via
## _input, and router intents (which also covers the voice and AT-bridge
## adapters, whose input never surfaces as engine events). The demo drives the
## game through the same InputRouter signals as a player, flagged so its own
## intents don't reset the idle clock.

signal demo_started
signal player_returned

## Seconds of total silence before the demo takes over.
@export var idle_after: float = 90.0

enum Phase { AIMING, DRAWING, HOLDING, PAUSING }

var _controller: ArcheryController
var _select: CharacterSelect
var _banner: CanvasLayer
var _active: bool = false
var _emitting: bool = false      # true while WE emit intents (ignore them)
var _idle: float = 0.0

var _phase: Phase = Phase.PAUSING
var _phase_t: float = 0.0
var _aim_from: Vector2 = Vector2.ZERO
var _aim_to: Vector2 = Vector2.ZERO
var _shots: int = 0

func setup(controller: ArcheryController, select: CharacterSelect) -> void:
	_controller = controller
	_select = select

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_banner()
	# Router intents count as activity (covers voice & AT-bridge devices).
	InputRouter.aim_axis.connect(func(_v): _touch())
	InputRouter.aim_absolute.connect(func(_v): _touch())
	InputRouter.draw_pressed.connect(_touch)
	InputRouter.steady_pressed.connect(_touch)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_touch()
	elif event is InputEventJoypadButton and event.pressed:
		_touch()
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_touch()
	elif event is InputEventMouseButton and event.pressed:
		_touch()
	elif event is InputEventMouseMotion and event.relative.length() > 6.0:
		_touch()

func _touch() -> void:
	if _emitting:
		return
	_idle = 0.0
	if _active:
		_wake()

func _process(delta: float) -> void:
	if not _active:
		_idle += delta
		if _idle >= idle_after:
			_start()
		return
	_run_demo(delta)

# --- demo lifecycle -------------------------------------------------------------

func _start() -> void:
	_active = true
	_shots = 0
	_banner.visible = true
	# If the idle station is sitting on the select screen, the demo picks a
	# random athlete and gets on with the show.
	if _select != null and _select.is_open():
		_pick_random_athlete()
	_phase = Phase.PAUSING
	_phase_t = 1.0
	demo_started.emit()

func _wake() -> void:
	_active = false
	_banner.visible = false
	_idle = 0.0
	# Let any half-drawn demo shot down cleanly.
	_emit_intents(func(): InputRouter.draw_released.emit())
	player_returned.emit()

func _pick_random_athlete() -> void:
	var index := randi() % AthleteRoster.ATHLETES.size()
	if _select != null and _select.is_open():
		_select._set_selected(index, false)
		_select._confirm()
	else:
		AssistSettings.athlete_index = index
		AssistSettings.changed.emit()

# --- the demo archer ------------------------------------------------------------

func _run_demo(delta: float) -> void:
	_phase_t -= delta
	match _phase:
		Phase.PAUSING:
			if _phase_t <= 0.0:
				# A new athlete steps up every few ends.
				if _shots % 3 == 0 and _shots > 0:
					_pick_random_athlete()
				_aim_from = _aim_to
				_aim_to = _pick_aim()
				_phase = Phase.AIMING
				_phase_t = 1.4
		Phase.AIMING:
			var k := clampf(1.0 - _phase_t / 1.4, 0.0, 1.0)
			var aim := _aim_from.lerp(_aim_to, k)
			_emit_intents(func(): InputRouter.aim_absolute.emit(aim))
			if _phase_t <= 0.0:
				_emit_intents(func(): InputRouter.draw_pressed.emit())
				_phase = Phase.DRAWING
				_phase_t = AssistSettings.full_draw_seconds + 0.35
		Phase.DRAWING:
			if _phase_t <= 0.0:
				_emit_intents(func(): InputRouter.draw_released.emit())
				_shots += 1
				_phase = Phase.PAUSING
				_phase_t = 3.0
		Phase.HOLDING:
			pass

## Aim (in absolute-intent space) at a random target, compensating gravity
## drop, with a sprinkle of human error so the demo looks played, not scripted.
func _pick_aim() -> Vector2:
	var targets := get_tree().get_nodes_in_group("targets")
	if targets.is_empty() or _controller == null:
		return Vector2(randf_range(-0.3, 0.3), randf_range(0.05, 0.25))
	var target: Node3D = targets[randi() % targets.size()]
	var d: Vector3 = target.global_position - _controller.global_position
	var horizontal := Vector2(d.x, d.z).length()
	var flight_t := horizontal / _controller.max_launch_speed
	var drop := 0.5 * 14.0 * flight_t * flight_t
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y + drop, horizontal)
	var aim := Vector2(-yaw / _controller.absolute_yaw_range, pitch / _controller.absolute_pitch_range)
	aim += Vector2(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))
	return aim.clamp(Vector2(-1, -1), Vector2(1, 1))

func _emit_intents(emitter: Callable) -> void:
	_emitting = true
	emitter.call()
	_emitting = false

# --- banner ---------------------------------------------------------------------

func _build_banner() -> void:
	_banner = CanvasLayer.new()
	_banner.layer = 24
	_banner.visible = false
	add_child(_banner)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-280, 84)
	panel.custom_minimum_size = Vector2(560, 0)
	_banner.add_child(panel)
	var label := Label.new()
	label.text = "AUTO DEMO  —  touch any control to play"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	panel.add_child(label)
