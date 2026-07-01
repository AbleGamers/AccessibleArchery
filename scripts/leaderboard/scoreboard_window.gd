extends Window
class_name ScoreboardWindow
## A second-display audience scoreboard.
##
## Godot 4 can open extra *native* OS windows simply by adding a `Window` node to
## the tree. We use that to put the leaderboard on its own monitor while the game
## runs on the primary display — a single process, sharing the same game state.
##
## Key choices:
##   * FLAG_NO_FOCUS — the scoreboard never steals keyboard focus, so all input
##     keeps flowing to the game window.
##   * If a second monitor exists, it fills that screen borderless. On a single
##     monitor (dev machine) it opens as a normal side window so you can still
##     test everything without a second display.

var _current_label: Label
var _match_label: Label
var _list_label: Label
var _current: int = 0

func _ready() -> void:
	title = "Accessible Archery — Scoreboard"
	set_flag(Window.FLAG_NO_FOCUS, true)
	# Float above the game window so toggling it on (B / menu) actually surfaces
	# it on a single monitor instead of opening behind the game.
	set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	_place_on_second_screen()
	_build_ui()
	Leaderboard.updated.connect(_refresh_list)
	_refresh_list()

func set_current(score: int) -> void:
	_current = score
	if _current_label != null:
		_current_label.text = "SCORE  %d" % score

func set_match(text: String) -> void:
	if _match_label != null:
		_match_label.text = text

func _place_on_second_screen() -> void:
	if DisplayServer.get_screen_count() > 1:
		# Real second monitor: fill it, borderless, like a stadium display.
		var screen := 1
		borderless = true
		position = DisplayServer.screen_get_position(screen)
		size = DisplayServer.screen_get_size(screen)
	else:
		# Single monitor: a smaller window tucked into the bottom-right corner,
		# hidden by default so it never covers the game. Toggle it with B; drag
		# it anywhere by its title bar.
		borderless = false
		size = Vector2i(360, 480)
		var screen_size := DisplayServer.screen_get_size(0)
		var screen_pos := DisplayServer.screen_get_position(0)
		position = screen_pos + Vector2i(screen_size.x - size.x - 40, screen_size.y - size.y - 70)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	var heading := _label("ACCESSIBLE ARCHERY", 40, Color(0.60, 0.80, 1.0))
	vb.add_child(heading)

	_current_label = _label("SCORE  0", 96, Color(1.0, 0.85, 0.10))
	vb.add_child(_current_label)

	_match_label = _label("Sets — You 0 : 0 CPU   (Set 1)", 30, Color(0.75, 0.90, 0.80))
	vb.add_child(_match_label)

	vb.add_child(_label("TOP SCORES", 28, Color.WHITE))

	_list_label = _label("", 30, Color(0.85, 0.90, 1.0))
	vb.add_child(_list_label)

func _refresh_list() -> void:
	if _list_label == null:
		return
	var lines := PackedStringArray()
	var rank := 1
	for e in Leaderboard.top(8):
		lines.append("%d.  %-12s  %d" % [rank, e["name"], e["score"]])
		rank += 1
	if lines.is_empty():
		lines.append("(no scores yet — press L to bank a run)")
	_list_label.text = "\n".join(lines)

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
