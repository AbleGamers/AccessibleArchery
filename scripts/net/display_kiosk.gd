extends Node
## Root of the display scene (`--display`). Read-only network client and the
## back-of-booth "attract mode" kiosk: large high-contrast board, an
## input-method badge per row (the mission statement — see doc), a "NEW HIGH
## SCORE!" pop, and a rotation between the board and a how-to-play slide.
##
## Rotates TODAY ↔ BEST OF SHOW ↔ how-to-play, matching the doc's daily
## rollover scoping (see leaderboard_store.gd).

const ROTATE_SECONDS := 12.0
const CELEBRATION_SECONDS := 4.0

## AssistSettings.InputScheme -> [icon, short label], matching the doc's
## "MAYA 280 🎙 Voice" mock. -1 = unknown/legacy entry (pre-network score).
const _BADGES := {
	AssistSettings.InputScheme.KEYBOARD_MOUSE: ["⌨", "Keyboard"],
	AssistSettings.InputScheme.GAMEPAD: ["🎮", "Gamepad"],
	AssistSettings.InputScheme.SINGLE_SWITCH: ["🕹", "Switch"],
	AssistSettings.InputScheme.EYE_TRACKING: ["👁", "Eye-tracking"],
	AssistSettings.InputScheme.VOICE: ["🎙", "Voice"],
}

var _status_label: Label
var _today_rows: VBoxContainer
var _all_time_rows: VBoxContainer
var _info_panel: Control
var _celebration: Label
var _today_snapshot: Array = []
var _all_time_snapshot: Array = []
var _top_ts: float = -1.0

var _panels: Array[Control] = []
var _panel_index: int = 0
var _rotate_timer: Timer
var _celebration_timer: Timer

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Fullscreen by default (this scene's whole job is being the kiosk); pass
	# --windowed during dev testing so it doesn't take over your screen.
	if not Role.windowed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Best-effort kiosk lockdown: swallow the window close request so a
	# passerby can't accidentally quit the kiosk. This is not OS-level
	# lockdown (Alt-Tab, Cmd+Q handling, etc. are a staff/runbook concern —
	# see docs/BOOTH_RUNBOOK.md); it just stops the one thing Godot can stop
	# on its own.
	get_tree().set_auto_accept_quit(false)

	_build_ui()
	LeaderboardNet.updated.connect(_on_updated)
	LeaderboardNet.connection_state_changed.connect(_on_connection_state_changed)
	_on_connection_state_changed(LeaderboardNet.is_connected_to_server())

	_rotate_timer = Timer.new()
	_rotate_timer.wait_time = ROTATE_SECONDS
	_rotate_timer.autostart = true
	_rotate_timer.timeout.connect(_rotate_panel)
	add_child(_rotate_timer)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	bg.add_child(root)

	root.add_child(_label("ACCESSIBLE ARCHERY", 48, Color(0.60, 0.80, 1.0)))
	_status_label = _label("Connecting…", 20, Color(0.70, 0.70, 0.70))
	root.add_child(_status_label)

	var panel_host := Control.new()
	panel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel_host)

	var today_panel := _build_board_panel("TODAY'S LEADERBOARD")
	_today_rows = today_panel.get_node("Rows") as VBoxContainer
	var all_time_panel := _build_board_panel("BEST OF SHOW")
	_all_time_rows = all_time_panel.get_node("Rows") as VBoxContainer
	_info_panel = _build_info_panel()
	panel_host.add_child(today_panel)
	panel_host.add_child(all_time_panel)
	panel_host.add_child(_info_panel)
	_panels = [today_panel, all_time_panel, _info_panel]
	for p in _panels:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show_panel(0)

	_celebration = _label("🎉 NEW HIGH SCORE! 🎉", 56, Color(1.0, 0.85, 0.15))
	_celebration.set_anchors_preset(Control.PRESET_CENTER)
	_celebration.visible = false
	add_child(_celebration)

func _build_board_panel(title: String) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.add_child(_label(title, 30, Color(0.85, 0.90, 1.0)))
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 6)
	vb.add_child(rows)
	return vb

func _build_info_panel() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.add_child(_label("HOW TO PLAY", 30, Color(0.85, 0.90, 1.0)))
	vb.add_child(_label(
		"Aim, draw, and release — with whatever device works for you.",
		24, Color(0.90, 0.90, 0.90)))
	vb.add_child(_label(
		"Keyboard  •  Gamepad  •  Single Switch  •  Eye Tracking  •  Voice",
		24, Color(0.75, 0.90, 0.80)))
	vb.add_child(_label(
		"Everyone plays the same game. The device never changes the rules.",
		22, Color(0.70, 0.85, 1.0)))
	return vb

func _on_connection_state_changed(is_connected: bool) -> void:
	_status_label.text = "Connected to %s" % Role.server_ip if is_connected else "Connecting…"

func _on_updated(today: Array, all_time: Array) -> void:
	_today_snapshot = today
	_all_time_snapshot = all_time
	_maybe_celebrate()
	_rebuild_rows(_today_rows, _today_snapshot)
	_rebuild_rows(_all_time_rows, _all_time_snapshot)

func _maybe_celebrate() -> void:
	# Today's board is what visitors are actively chasing — that's what
	# "a station banks a top entry" means in practice.
	if _today_snapshot.is_empty():
		return
	var new_top_ts: float = _today_snapshot[0].get("ts", -1.0)
	if _top_ts >= 0.0 and new_top_ts != _top_ts:
		_show_celebration()
	_top_ts = new_top_ts

func _show_celebration() -> void:
	_celebration.visible = true
	if _celebration_timer != null:
		_celebration_timer.stop()
		_celebration_timer.queue_free()
	_celebration_timer = Timer.new()
	_celebration_timer.wait_time = CELEBRATION_SECONDS
	_celebration_timer.one_shot = true
	_celebration_timer.timeout.connect(func(): _celebration.visible = false)
	add_child(_celebration_timer)
	_celebration_timer.start()

func _rebuild_rows(rows: VBoxContainer, snapshot: Array) -> void:
	for c in rows.get_children():
		c.queue_free()
	if snapshot.is_empty():
		rows.add_child(_label("(no scores yet — first player is up!)", 26, Color(0.6, 0.6, 0.6)))
		return
	var rank := 1
	for e in snapshot:
		rows.add_child(_build_row(rank, e))
		rank += 1

func _build_row(rank: int, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.add_child(_label("%2d." % rank, 28, Color(0.6, 0.7, 0.9)))
	var name_label := _label(str(entry.get("name", "?")), 28, Color(1.0, 0.95, 0.80))
	name_label.custom_minimum_size = Vector2(260, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var score_label := _label(str(entry.get("score", 0)), 28, Color.WHITE)
	score_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(score_label)
	var badge: Array = _BADGES.get(entry.get("input", -1), ["", "Unknown"])
	row.add_child(_label("%s %s" % [badge[0], badge[1]], 24, Color(0.75, 0.90, 0.85)))
	return row

func _rotate_panel() -> void:
	_panel_index = (_panel_index + 1) % _panels.size()
	_show_panel(_panel_index)

func _show_panel(index: int) -> void:
	for i in _panels.size():
		_panels[i].visible = i == index

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
