extends CanvasLayer
class_name BroadcastScoreboard
## In-game broadcast scoreboard overlay (concept art, image 2): a compact
## top-left panel with a row per archer — set points, then each arrow of the
## current set — in a clean TV-sports style. Reads live from the MatchManager.

const ARROW_CELLS := 3

var _set_label: Label
var _you_cells: Array[Label] = []   # [set points, arrow1, arrow2, arrow3]
var _cpu_cells: Array[Label] = []

func _ready() -> void:
	layer = 9

	var root := VBoxContainer.new()
	root.position = Vector2(16, 14)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	_set_label = Label.new()
	_set_label.add_theme_font_size_override("font_size", 16)
	_set_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_set_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_set_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_set_label)

	var grid := GridContainer.new()
	grid.columns = 2 + ARROW_CELLS   # name | set pts | arrow x3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	root.add_child(grid)

	_build_row(grid, "YOU", _you_cells)
	_build_row(grid, "CPU", _cpu_cells)

## Rebuild cell contents from the current match state.
func refresh(m: MatchManager) -> void:
	_set_label.text = "SET %d   ·   first to %d" % [m.current_set, MatchManager.SET_POINTS_TO_WIN]
	_fill_row(_you_cells, m.player_set_points, m.player_arrows)
	_fill_row(_cpu_cells, m.cpu_set_points, m.cpu_arrows)

# --- construction -------------------------------------------------------------

func _build_row(grid: GridContainer, name_text: String, cells: Array[Label]) -> void:
	grid.add_child(_cell(name_text, Color(0.93, 0.93, 0.93), Color(0.08, 0.10, 0.14), 92, 20))
	# Set-points cell (dark, highlighted — the headline number).
	cells.append(_grid_value_cell(grid, Color(0.12, 0.14, 0.20), Color.WHITE, 22))
	# Per-arrow cells (mid grey).
	for _i in ARROW_CELLS:
		cells.append(_grid_value_cell(grid, Color(0.62, 0.66, 0.72), Color(0.08, 0.10, 0.14), 18))

func _grid_value_cell(grid: GridContainer, bg: Color, fg: Color, font_size: int) -> Label:
	var panel := _cell("", bg, fg, 46, font_size)
	grid.add_child(panel)
	return panel.get_child(0) as Label

func _cell(text: String, bg: Color, fg: Color, min_w: int, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_w, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", fg)
	panel.add_child(label)
	return panel

# --- update -------------------------------------------------------------------

func _fill_row(cells: Array[Label], set_points: int, arrows: Array[int]) -> void:
	cells[0].text = str(set_points)
	for i in ARROW_CELLS:
		cells[i + 1].text = str(arrows[i]) if i < arrows.size() else ""
