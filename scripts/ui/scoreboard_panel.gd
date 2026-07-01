extends CanvasLayer
class_name ScoreboardPanel
## In-window scoreboard overlay (top-right), toggled with B / the options menu.
## Used on a single monitor where a separate OS window would fight the game for
## z-order; a real second monitor instead gets ScoreboardWindow. Same simple API
## (set_current / set_match) so the main scene can drive both interchangeably.

var _current_label: Label
var _match_label: Label
var _list_label: Label

func _ready() -> void:
	layer = 8
	_build_ui()
	Leaderboard.updated.connect(_refresh_list)
	_refresh_list()

func set_current(score: int) -> void:
	if _current_label != null:
		_current_label.text = "SCORE  %d" % score

func set_match(text: String) -> void:
	if _match_label != null:
		_match_label.text = text

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -360.0
	panel.offset_right = -16.0
	panel.offset_top = 70.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	vb.add_child(_label("LEADERBOARD", 22, Color(0.60, 0.80, 1.0)))
	_current_label = _label("SCORE  0", 44, Color(1.0, 0.85, 0.10))
	vb.add_child(_current_label)
	_match_label = _label("Sets — You 0 : 0 CPU   (Set 1)", 20, Color(0.75, 0.90, 0.80))
	vb.add_child(_match_label)
	vb.add_child(_label("TOP SCORES", 20, Color.WHITE))
	_list_label = _label("", 22, Color(0.85, 0.90, 1.0))
	vb.add_child(_list_label)

func _refresh_list() -> void:
	if _list_label == null:
		return
	var lines := PackedStringArray()
	var rank := 1
	for e in Leaderboard.top(8):
		lines.append("%d.  %-10s  %d" % [rank, e["name"], e["score"]])
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
