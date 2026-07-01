extends Node
class_name MatchManager
## Olympic-style match flow (per the GDD), driven entirely by the player's
## resolved shots. Pure logic — no scene/UI knowledge — so it is easy to test
## and reuse. `main.gd` feeds it shots via record_player_shot() and renders
## `status_lines()` / reacts to `changed`.
##
## Rules:
##   * A set = each archer shoots 3 arrows; higher ring total wins the set.
##   * Set won = 2 set points; a tied set = 1 point each.
##   * First to 6 set points wins the match.
##   * 6–6 (both reach 6 on a tying set) triggers a single-arrow sudden-death
##     shootout, replayed until someone wins.
##
## The opponent is a CPU whose accuracy scales up as the match progresses.

signal changed

enum Phase { PLAYER_TURN, SET_RESULT, TIEBREAK, MATCH_OVER }

const ARROWS_PER_SET := 3
const SET_POINTS_TO_WIN := 6

var phase: Phase = Phase.PLAYER_TURN
var current_set: int = 1
var player_set_points: int = 0
var cpu_set_points: int = 0
var player_arrows: Array[int] = []
var cpu_arrows: Array[int] = []
var message: String = "Set 1 — shoot 3 arrows."

func _ready() -> void:
	randomize()

## Feed every resolved player shot here (ring score; 0 on a miss).
func record_player_shot(score: int) -> void:
	match phase:
		Phase.PLAYER_TURN:
			_add_player_arrow(score)
		Phase.SET_RESULT:
			# Seamless: the first shot of the next set begins it.
			_start_next_set()
			_add_player_arrow(score)
		Phase.TIEBREAK:
			_resolve_tiebreak(score)
		Phase.MATCH_OVER:
			pass   # ignore until reset()
	changed.emit()

func reset() -> void:
	phase = Phase.PLAYER_TURN
	current_set = 1
	player_set_points = 0
	cpu_set_points = 0
	player_arrows.clear()
	cpu_arrows.clear()
	message = "Set 1 — shoot 3 arrows."
	changed.emit()

func status_lines() -> Array[String]:
	var lines: Array[String] = [
		"Match — Set %d        Set points: You %d – CPU %d  (first to %d)"
			% [current_set, player_set_points, cpu_set_points, SET_POINTS_TO_WIN],
		"This set: You %s  |  arrows %d/%d"
			% [_format_arrows(player_arrows), player_arrows.size(), ARROWS_PER_SET],
		message,
	]
	return lines

# --- internals ----------------------------------------------------------------

func _add_player_arrow(score: int) -> void:
	player_arrows.append(score)
	var shot := _sum(player_arrows)
	message = "Set %d — arrow %d/%d, set total %d." % [current_set, player_arrows.size(), ARROWS_PER_SET, shot]
	if player_arrows.size() >= ARROWS_PER_SET:
		_finish_set()

func _finish_set() -> void:
	cpu_arrows = _cpu_play_set()
	var p := _sum(player_arrows)
	var c := _sum(cpu_arrows)
	var outcome: String
	if p > c:
		player_set_points += 2
		outcome = "you win the set (+2)"
	elif c > p:
		cpu_set_points += 2
		outcome = "CPU wins the set (+2)"
	else:
		player_set_points += 1
		cpu_set_points += 1
		outcome = "tied set (+1 each)"
	phase = Phase.SET_RESULT
	message = "Set %d: You %d – CPU %d → %s.  Shoot to start set %d." % [current_set, p, c, outcome, current_set + 1]
	_check_victory()

func _check_victory() -> void:
	var p_win := player_set_points >= SET_POINTS_TO_WIN
	var c_win := cpu_set_points >= SET_POINTS_TO_WIN
	if p_win and c_win:
		phase = Phase.TIEBREAK
		message = "%d–%d! Sudden-death shootout — shoot ONE arrow." % [player_set_points, cpu_set_points]
	elif p_win:
		phase = Phase.MATCH_OVER
		message = "MATCH! You win %d–%d. Press R for a rematch." % [player_set_points, cpu_set_points]
	elif c_win:
		phase = Phase.MATCH_OVER
		message = "Match over — CPU wins %d–%d. Press R for a rematch." % [cpu_set_points, player_set_points]

func _resolve_tiebreak(player_score: int) -> void:
	var cpu_score := _cpu_arrow()
	if player_score > cpu_score:
		phase = Phase.MATCH_OVER
		message = "Shootout: You %d – CPU %d. You WIN the match! Press R to rematch." % [player_score, cpu_score]
	elif cpu_score > player_score:
		phase = Phase.MATCH_OVER
		message = "Shootout: You %d – CPU %d. CPU wins. Press R to rematch." % [player_score, cpu_score]
	else:
		message = "Shootout tied %d–%d — shoot again!" % [player_score, cpu_score]

func _start_next_set() -> void:
	current_set += 1
	player_arrows.clear()
	cpu_arrows.clear()
	phase = Phase.PLAYER_TURN
	message = "Set %d — shoot 3 arrows." % current_set

# CPU accuracy scales up each set (the GDD's "scaling CPU opponent").
func _cpu_skill() -> float:
	return clampf(0.40 + 0.06 * float(current_set - 1), 0.40, 0.85)

func _cpu_play_set() -> Array[int]:
	var arrows: Array[int] = []
	for _i in ARROWS_PER_SET:
		arrows.append(_cpu_arrow())
	return arrows

func _cpu_arrow() -> int:
	var skill := _cpu_skill()
	var roll := randf()
	var p_ten := lerpf(0.15, 0.55, skill)   # bullseye chance rises with skill
	var p_five := 0.30
	var p_one := 0.30
	if roll < p_ten:
		return 10
	elif roll < p_ten + p_five:
		return 5
	elif roll < p_ten + p_five + p_one:
		return 1
	return 0   # miss

func _sum(arr: Array[int]) -> int:
	var total := 0
	for v in arr:
		total += v
	return total

func _format_arrows(arr: Array[int]) -> String:
	if arr.is_empty():
		return "—"
	var parts := PackedStringArray()
	for v in arr:
		parts.append(str(v))
	return "+".join(parts)
