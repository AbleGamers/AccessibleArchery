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
var _impact_cam: ImpactCam
var _venue: MeadowRange
var _select: CharacterSelect
var _playstyle: PlaystyleSelect
var _device_switcher: DeviceSwitcher
var _sfx: SfxSystem
var _attract: AttractMode
var _prev_match_phase: int = MatchManager.Phase.PLAYER_TURN
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

	# The archer is at +Z looking down the range toward -Z; the shooting height
	# follows the selected athlete (standing vs wheelchair).
	_controller = ArcheryController.new()
	_controller.position = Vector3(0.0, AthleteRoster.eye_height(AssistSettings.athlete_index), 6.0)
	add_child(_controller)
	AssistSettings.changed.connect(func():
		_controller.position.y = AthleteRoster.eye_height(AssistSettings.athlete_index))
	_controller.aim_updated.connect(_on_aim_updated)
	_controller.shot_resolved.connect(_on_shot_resolved)
	_controller.arrow_fired.connect(_on_arrow_fired)
	_controller.full_draw_reached.connect(_on_full_draw)
	_controller.draw_cancelled.connect(_on_draw_cancelled)
	_controller.steady_started.connect(func(): _channel.announce("Steady — breath held"))
	_controller.breath_exhausted.connect(_on_breath_exhausted)

	_add_target(Vector3(0.0, 1.6, -14.0))
	_add_target(Vector3(-4.0, 1.2, -22.0))
	_add_target(Vector3(4.0, 2.1, -30.0))

	# Broadcast-style target cam for the shot (optional, AssistSettings).
	_impact_cam = ImpactCam.new()
	add_child(_impact_cam)

	_audio = AudioCueSystem.new()
	add_child(_audio)

	# Procedural sound identity: whoosh/thunk, crowd, fanfare (all captioned
	# elsewhere — this layer is atmosphere, never sole information).
	_sfx = SfxSystem.new()
	add_child(_sfx)

	# "Second Channel" — sight + sound + touch parity for every critical cue.
	_channel = SecondChannelHUD.new()
	add_child(_channel)
	_haptics = HapticSystem.new()
	add_child(_haptics)
	Wind.shifted.connect(_on_wind_shift)
	# Transient chatter is caption-only (speak = false): the draw tone and the
	# release whoosh already ARE the audio versions of these two.
	InputRouter.draw_pressed.connect(func(): _channel.announce("Drawing…", false))
	InputRouter.draw_released.connect(func(): _channel.announce("Loosed!", false))

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

	# Athlete select (P reopens). Opened after the play-style is chosen, or
	# straight away on later launches / at a configured booth station.
	_select = CharacterSelect.new()
	add_child(_select)

	# Playtest device switcher (backtick). Hidden by default; players pick their
	# device up front, so the number-key chooser is no longer a persistent HUD.
	_device_switcher = DeviceSwitcher.new()
	add_child(_device_switcher)

	# "How do you want to play?" — first-run accessibility-preset picker. Shown
	# once (before athlete select) so a new player sets up their experience and a
	# blind player discovers audio-guided play by ear; then it hands off to the
	# athlete select. Reopened from the options menu (Change play style).
	_playstyle = PlaystyleSelect.new()
	add_child(_playstyle)
	_playstyle.chosen.connect(func(_i):
		_controller.position.y = AthleteRoster.eye_height(AssistSettings.athlete_index)
		_select.open())
	_menu.playstyle_requested.connect(_playstyle.open)

	# First run picks a play style; returning players/stations skip straight to
	# the athlete select (their preset persists). Auto-detect a gamepad on the
	# very first launch so "Standard" needs no manual device choice.
	if not AssistSettings.setup_complete:
		_autodetect_device()
		_playstyle.open()
	else:
		_select.open()

	# Booth resilience: idle → self-running demo; first real input resets the
	# station (fresh match + athlete select) for the next player.
	_attract = AttractMode.new()
	add_child(_attract)
	_attract.setup(_controller, _select, _playstyle)
	_attract.player_returned.connect(_on_player_returned)

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
		KEY_P:   # (re)open the athlete select
			if not _select.is_open():
				_select.open()
		KEY_ESCAPE:   # open / close the accessibility & options menu
			_menu.toggle()
		KEY_QUOTELEFT:   # backtick — playtest device switcher (press 1-6 to swap)
			_device_switcher.toggle()

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

# First-launch convenience: if a gamepad is plugged in and the player hasn't
# chosen a device yet, default to it — so a booth walk-up on a controller never
# has to find the device menu. A deliberate choice on a later launch (persisted
# input_scheme) is never overridden, since this only runs when setup isn't done.
func _autodetect_device() -> void:
	if AssistSettings.input_scheme == AssistSettings.InputScheme.KEYBOARD_MOUSE \
			and not Input.get_connected_joypads().is_empty():
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.GAMEPAD)

func _on_player_returned() -> void:
	_match.reset()
	_score = 0
	_set_boards_current()
	# A configured station drops the next player straight into athlete select;
	# an unconfigured one (first run not finished) resumes at the play-style pick.
	if AssistSettings.setup_complete:
		_select.open()
	else:
		_playstyle.open()
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
	# nearest target centre, which side that target is on, and the elevation
	# error (for the two-note vertical cue).
	var t := _targeting()
	_audio.set_targeting(t.x, t.y, t.z)
	_audio.set_instability(_controller.sway_instability())
	# The steady-breath metronome: while held breath locks the aim, the audio
	# system ticks the release window down by ear.
	_audio.set_breath(_controller.breath_fraction(), _controller.is_steady())
	_haptics.update(t.x, t.y)
	# The crowd hushes while the bow is drawn — dramatic, and it guarantees the
	# ambience never masks the aiming cues during a blindfolded shot.
	_sfx.set_duck(1.0 if _controller.is_drawing() else 0.0)
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

func _on_arrow_fired(arrow: Node) -> void:
	_sfx.shot_loosed()
	if AssistSettings.impact_cam_enabled:
		_impact_cam.follow(arrow, _nearest_target())

func _on_shot_resolved(score: int, offset: Vector2) -> void:
	# The thunk/ding pan to where the arrow struck the face (x in face radii),
	# so a blind player hears "left of centre" from the impact itself.
	_sfx.arrow_scored(score, offset.x)
	_score += score                       # cumulative ring points (leaderboard-able)
	_set_boards_current()
	_channel.announce(_score_callout(score, offset))
	_match.record_player_shot(score)      # drives set/match logic
	_refresh_hud()

func _on_full_draw() -> void:
	_channel.flash_draw_snap()
	_channel.announce("Full draw", false)   # the chirp IS the audio version
	_audio.full_draw_chirp()
	_haptics.snap()

func _on_breath_exhausted() -> void:
	# Over-hold warning on all three channels: caption + haptic here; the audio
	# side is the draw tone's sway wobble (AudioCueSystem.set_instability).
	_channel.announce("Breath spent — sway rising!")
	_haptics.breath_lost()

func _on_draw_cancelled() -> void:
	# Feedback on all three channels: caption, audio blip, haptic buzz.
	_channel.announce("Draw cancelled — hold to full draw")
	_audio.blip()
	_haptics.cancel()

func _on_wind_shift(lateral: float, kmh: float) -> void:
	var dir := "←" if lateral < -0.1 else ("→" if lateral > 0.1 else "·")
	_channel.announce("Wind shift  %s  %d km/h" % [dir, int(round(kmh))])

func _on_match_changed() -> void:
	if _match.phase == MatchManager.Phase.MATCH_OVER and _prev_match_phase != MatchManager.Phase.MATCH_OVER:
		_sfx.match_fanfare(_match.player_won)
	_prev_match_phase = _match.phase
	_set_boards_match("Sets — You %d : %d CPU   (Set %d)" % [
		_match.player_set_points, _match.cpu_set_points, _match.current_set])
	if _venue != null:
		if _match.phase == MatchManager.Phase.MATCH_OVER:
			_venue.set_jumbotron("MATCH OVER", "YOU %d — %d CPU" % [
				_match.player_set_points, _match.cpu_set_points])
		else:
			_venue.set_jumbotron("SET %d" % _match.current_set, "YOU %d — %d CPU" % [
				_match.player_set_points, _match.cpu_set_points])
	if _broadcast != null:
		_broadcast.refresh(_match)
	if _channel != null and _match.phase != MatchManager.Phase.PLAYER_TURN:
		_channel.announce(_match.message)
	_refresh_hud()

func _score_callout(score: int, offset: Vector2 = Vector2.ZERO) -> String:
	var base := "Miss"
	if score >= 10:
		return "Bullseye!  +10"   # dead centre by definition — no direction
	elif score >= 9:
		base = "Gold  +9"
	elif score >= 7:
		base = "Red  +%d" % score
	elif score >= 5:
		base = "Blue  +%d" % score
	elif score >= 3:
		base = "Black  +%d" % score
	elif score >= 1:
		base = "White  +%d" % score
	else:
		return base
	var direction := _impact_direction(offset)
	return base if direction == "" else "%s — %s" % [base, direction]

# Archery-caller direction of the strike from the face centre ("high left"),
# spoken with the score so a blind player knows which way to correct. A
# component only counts when it is a meaningful share of the miss, so a shot
# barely above dead-left reads "left", not "high left".
func _impact_direction(offset: Vector2) -> String:
	var parts := PackedStringArray()
	if absf(offset.y) > 0.12 and absf(offset.y) > 0.4 * absf(offset.x):
		parts.append("high" if offset.y > 0.0 else "low")
	if absf(offset.x) > 0.12 and absf(offset.x) > 0.4 * absf(offset.y):
		parts.append("left" if offset.x < 0.0 else "right")
	return " ".join(parts)

# Returns (accuracy 0..1, lateral -1..+1, vertical -1..+1) for the nearest
# target to the aim. vertical > 0 means the target is above the aim (aim UP).
func _targeting() -> Vector3:
	if _controller == null:
		return Vector3.ZERO
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
	var accuracy := clampf(1.0 - angle / deg_to_rad(AssistSettings.guidance_cone_deg), 0.0, 1.0)
	var lateral := clampf(_controller.right_axis().dot(best_to) * AssistSettings.pan_strength, -1.0, 1.0)
	var vertical := clampf((best_to.y - forward.y) * 6.0, -1.0, 1.0)
	return Vector3(accuracy, lateral, vertical)

func _setup_world() -> void:
	# Low-poly tournament meadow (sky, hills + trees, tents, flags, bleachers +
	# crowd, berm backstop, live LED screen). Kept as a member so match state can
	# drive the big screen.
	_venue = MeadowRange.new()
	add_child(_venue)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	# Anchored to the bottom-left and grown upward, so this device-help + run-total
	# panel sits under the downrange targets instead of over the player's aim line.
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hud.position = Vector2(20, -14)
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
		AssistSettings.controls_hint(),
		"",
		_match.message if _match != null else "",
		"",
		"Score: %d        Charge: %d%%        Breath: %d%%" % [_score,
			int(round(_charge * 100.0)),
			int(round((_controller.breath_fraction() if _controller != null else 1.0) * 100.0))],
		"Audio cues: %s" % ("ON" if AssistSettings.audio_cues_enabled else "off"),
		"Esc: options   P: athlete   L: bank   R: end/restart   V: flip camera   B: scoreboard   `: devices",
	])
	_hud.text = "\n".join(lines)
