extends Node3D
## 3D range — vertical slice wiring.
##
## Builds a small but proper archery range (ground, sky, sun, three targets at
## varying distance/height) entirely in code, so the project runs with ZERO art
## assets. The point of the slice is to prove the architecture: the same
## draw/aim/release loop is playable on keyboard, gamepad, single-switch scan,
## eye-tracking, AND voice — plus audio-only cues — with no gameplay code aware
## of the device in use.
##
## Replace the code-built environment with authored .tscn scenes and real art
## whenever you like; the input and gameplay layers will not change.

var _controller: ArcheryController
var _audio: AudioCueSystem
var _hud: Label
var _channel: SecondChannelHUD
var _haptics: HapticSystem
var _reticle: MeshInstance3D
var _scoreboard: ScoreboardWindow      # only on a real second monitor
var _panel: ScoreboardPanel            # in-window overlay (single monitor)
var _broadcast: BroadcastScoreboard
var _menu: OptionsMenu
var _name_prompt: NamePrompt
var _match: MatchManager
var _score: int = 0
var _aim: Vector2 = Vector2.ZERO
var _charge: float = 0.0

func _ready() -> void:
	# Booth deployment passes --kiosk (see docs/BOOTH_RUNBOOK.md); dev/editor
	# play stays windowed so iteration never has to fight a fullscreen window.
	if Role.kiosk:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_tree().set_auto_accept_quit(false)

	_setup_world()

	# The archer stands at +Z looking down the range toward -Z, at eye height.
	_controller = ArcheryController.new()
	_controller.position = Vector3(0.0, 1.6, 6.0)
	add_child(_controller)
	_controller.aim_updated.connect(_on_aim_updated)
	_controller.shot_resolved.connect(_on_shot_resolved)
	_controller.full_draw_reached.connect(_on_full_draw)
	_controller.draw_cancelled.connect(_on_draw_cancelled)

	_add_target(Vector3(0.0, 1.6, -14.0))
	_add_target(Vector3(-4.0, 1.2, -22.0))
	_add_target(Vector3(4.0, 2.1, -30.0))

	_audio = AudioCueSystem.new()
	add_child(_audio)

	# "Second Channel" — sight + sound + touch parity for every critical cue.
	_channel = SecondChannelHUD.new()
	add_child(_channel)
	_haptics = HapticSystem.new()
	add_child(_haptics)
	Wind.shifted.connect(_on_wind_shift)
	InputRouter.draw_pressed.connect(func(): _channel.announce("Drawing…"))
	InputRouter.draw_released.connect(func(): _channel.announce("Loosed!"))

	# Olympic-style match flow (sets, set points, victory, tie-break vs CPU).
	_match = MatchManager.new()
	add_child(_match)
	_match.changed.connect(_on_match_changed)

	# Broadcast scoreboard overlay (concept art, image 2).
	_broadcast = BroadcastScoreboard.new()
	add_child(_broadcast)

	_build_reticle()

	# Scoreboard: an in-window overlay (toggle with B / menu) plus, only when a
	# real second monitor exists, a separate window that fills that screen.
	_panel = ScoreboardPanel.new()
	add_child(_panel)
	if DisplayServer.get_screen_count() > 1:
		_scoreboard = ScoreboardWindow.new()
		add_child(_scoreboard)
	AssistSettings.scoreboard_visible = false
	_sync_scoreboard()
	_set_boards_current()

	# Accessibility & options menu (Esc). Overlay, so hotkeys keep working.
	_menu = OptionsMenu.new()
	add_child(_menu)
	_name_prompt = NamePrompt.new()
	add_child(_name_prompt)

	_build_hud()
	AssistSettings.changed.connect(_refresh_hud)
	AssistSettings.changed.connect(_sync_scoreboard)
	_on_match_changed()
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_L:   # bank the current run onto the leaderboard
			_bank_score()
		KEY_R:   # rematch — reset the set/match state
			_match.reset()
		KEY_V:   # flip the camera to the other side of the archer
			AssistSettings.camera_on_left = not AssistSettings.camera_on_left
			AssistSettings.changed.emit()
		KEY_B:   # show / hide the scoreboard window (single-monitor convenience)
			AssistSettings.scoreboard_visible = not AssistSettings.scoreboard_visible
			AssistSettings.changed.emit()
		KEY_ESCAPE:   # open / close the accessibility & options menu
			_menu.toggle()

func _bank_score() -> void:
	if _name_prompt.is_open():
		return
	# First time, ask for a name (then remember it); afterwards bank silently.
	if AssistSettings.player_name.strip_edges() == "":
		_name_prompt.prompt("", func(entered: String):
			AssistSettings.player_name = entered
			AssistSettings.request_save()
			_do_bank(entered))
	else:
		_do_bank(AssistSettings.player_name)

func _do_bank(player_name: String) -> void:
	Leaderboard.add_score(player_name, _score, AssistSettings.input_scheme)
	LeaderboardNet.submit(player_name, _score, AssistSettings.input_scheme, "")
	_channel.announce("Banked %d for %s" % [_score, player_name])
	_score = 0
	_set_boards_current()
	_refresh_hud()

func _sync_scoreboard() -> void:
	# The setting toggles the in-window overlay; the second-monitor window (if
	# any) stays up on its own screen.
	if _panel != null:
		_panel.visible = AssistSettings.scoreboard_visible

func _set_boards_current() -> void:
	if _panel != null:
		_panel.set_current(_score)
	if _scoreboard != null:
		_scoreboard.set_current(_score)

func _set_boards_match(text: String) -> void:
	if _panel != null:
		_panel.set_match(text)
	if _scoreboard != null:
		_scoreboard.set_match(text)

func _add_target(pos: Vector3) -> void:
	var target := Target.new()
	target.position = pos
	add_child(target)

func _process(_delta: float) -> void:
	# Feed the audible + haptic centering cues with how close the aim is to the
	# nearest target centre, and which side that target is on.
	var t := _targeting()
	_audio.set_targeting(t.x, t.y)
	_haptics.update(t.x, t.y)
	_update_reticle()

func _build_reticle() -> void:
	# A solid sphere reads the same from any angle (no orientation to get wrong)
	# and, drawn on top, acts as a clear "you are aiming here" marker.
	_reticle = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.30
	dot.height = 0.60
	_reticle.mesh = dot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.20)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true        # always visible, like a HUD crosshair
	_reticle.material_override = mat
	add_child(_reticle)

# Park the reticle on the aim line at the nearest target's distance — so it
# shows exactly where the arrow is pointing.
func _update_reticle() -> void:
	if _reticle == null or _controller == null:
		return
	var origin := _controller.global_position
	var forward := _controller.aim_forward()
	var target := _nearest_target()
	var dist := origin.distance_to(target.global_position) if target != null else 18.0
	_reticle.global_position = origin + forward * dist

func _nearest_target() -> Node3D:
	var origin := _controller.global_position
	var forward := _controller.aim_forward()
	var best: Node3D = null
	var best_dot := -1.0
	for target in get_tree().get_nodes_in_group("targets"):
		var to: Vector3 = (target.global_position - origin).normalized()
		var d := forward.dot(to)
		if d > best_dot:
			best_dot = d
			best = target
	return best

func _on_aim_updated(aim_norm: Vector2, charge: float) -> void:
	_aim = aim_norm
	_charge = charge
	_audio.update_cue(aim_norm, charge, _controller.is_drawing())
	_refresh_hud()

func _on_shot_resolved(score: int) -> void:
	_score += score                       # cumulative ring points (leaderboard-able)
	_set_boards_current()
	_channel.announce(_score_callout(score))
	_match.record_player_shot(score)      # drives set/match logic
	_refresh_hud()

func _on_full_draw() -> void:
	_channel.flash_draw_snap()
	_channel.announce("Full draw")
	_haptics.snap()

func _on_draw_cancelled() -> void:
	# Feedback on all three channels: caption, audio blip, haptic buzz.
	_channel.announce("Draw cancelled — hold to full draw")
	_audio.blip()
	_haptics.cancel()

func _on_wind_shift(lateral: float, kmh: float) -> void:
	var dir := "←" if lateral < -0.1 else ("→" if lateral > 0.1 else "·")
	_channel.announce("Wind shift  %s  %d km/h" % [dir, int(round(kmh))])

func _on_match_changed() -> void:
	_set_boards_match("Sets — You %d : %d CPU   (Set %d)" % [
		_match.player_set_points, _match.cpu_set_points, _match.current_set])
	if _broadcast != null:
		_broadcast.refresh(_match)
	if _channel != null and _match.phase != MatchManager.Phase.PLAYER_TURN:
		_channel.announce(_match.message)
	_refresh_hud()

func _score_callout(score: int) -> String:
	match score:
		10: return "Bullseye!  +10"
		5:  return "Hit  +5"
		1:  return "On target  +1"
		_:  return "Miss"

# Returns (accuracy 0..1, lateral -1..+1) for the nearest target to the aim.
func _targeting() -> Vector2:
	if _controller == null:
		return Vector2.ZERO
	var origin := _controller.global_position
	var forward := _controller.aim_forward()
	var best_dot := -1.0
	var best_to := forward
	for target in get_tree().get_nodes_in_group("targets"):
		var to: Vector3 = (target.global_position - origin).normalized()
		var d := forward.dot(to)
		if d > best_dot:
			best_dot = d
			best_to = to
	var angle := acos(clampf(best_dot, -1.0, 1.0))
	var accuracy := clampf(1.0 - angle / deg_to_rad(12.0), 0.0, 1.0)
	var lateral := clampf(_controller.right_axis().dot(best_to) * 4.0, -1.0, 1.0)
	return Vector2(accuracy, lateral)

func _setup_world() -> void:
	# Low-poly Olympic arena (sky, stands + crowd, arch, floodlights, banners).
	add_child(Stadium.new())

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(20, 132)   # below the broadcast scoreboard panel
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)

func _refresh_hud() -> void:
	if _hud == null:
		return
	# The broadcast scoreboard (top-left) now shows set/arrow scores; this panel
	# keeps the device/controls help and run totals for testing.
	var lines := PackedStringArray([
		"Device [1 Keyboard  2 Gamepad  3 Switch  4 Eye  5 Voice]: %s" % AssistSettings.scheme_label(),
		"  %s" % AssistSettings.controls_hint(),
		"",
		_match.message if _match != null else "",
		"",
		"Score: %d        Charge: %d%%" % [_score, int(round(_charge * 100.0))],
		"Audio cues: %s" % ("ON" if AssistSettings.audio_cues_enabled else "off"),
		"Esc: options menu      L: bank   R: end/restart   V: flip camera   B: scoreboard",
	])
	_hud.text = "\n".join(lines)
