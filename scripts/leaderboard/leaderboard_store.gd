extends Node
## Local high-score store. Autoloaded as `Leaderboard`.
##
## Holds two scoped boards — see BOOTH_ARCHITECTURE.md "Leaderboard scoping
## for a multi-day con":
##   - `entries` — TODAY's top N. Resets each morning at ROLLOVER_HOUR so the
##     board stays fresh for new visitors walking up to the booth.
##   - `all_time_entries` — BEST OF SHOW. Persists across the whole event.
## Both persist to user:// as JSON. Rollover archives the outgoing day's
## board (and a full backup of the whole store) to a dated file before
## clearing today's bucket, so a multi-day con never loses a prior day.
## The on-screen scoreboard (a second-monitor window) simply reads from here
## and listens for `updated`.

signal updated

const SAVE_PATH := "user://leaderboard.json"
const ARCHIVE_DIR := "user://leaderboard_archive/"
const MAX_ENTRIES := 10
## Local hour (0-23) at which today's board rolls over. Chosen to land
## overnight, well outside booth hours.
const ROLLOVER_HOUR := 6

var entries: Array = []            # Array of { name, score, input, ts, station }
var all_time_entries: Array = []
var _last_rollover_date: String = ""
var _rollover_check_timer: Timer

func _ready() -> void:
	_load()
	_rollover_check_timer = Timer.new()
	_rollover_check_timer.wait_time = 60.0
	_rollover_check_timer.autostart = true
	_rollover_check_timer.timeout.connect(_check_rollover)
	add_child(_rollover_check_timer)
	_check_rollover()  # covers the app being (re)launched after ROLLOVER_HOUR

## `input_scheme` (AssistSettings.InputScheme) and `station_name` are optional
## so this stays the same call for a local/offline bank as it is for a
## network-authoritative one; -1 / "" mean "unknown".
func add_score(player_name: String, score: int, input_scheme := -1, station_name := "") -> void:
	var entry := {
		"name": player_name,
		"score": score,
		"input": input_scheme,
		"ts": Time.get_unix_time_from_system(),
		"station": station_name,
	}
	entries = _top_n(entries + [entry])
	all_time_entries = _top_n(all_time_entries + [entry])
	_save()
	updated.emit()

func top(n := MAX_ENTRIES) -> Array:
	return entries.slice(0, mini(n, entries.size()))

func top_all_time(n := MAX_ENTRIES) -> Array:
	return all_time_entries.slice(0, mini(n, all_time_entries.size()))

func clear() -> void:
	entries.clear()
	all_time_entries.clear()
	_save()
	updated.emit()

func _top_n(list: Array) -> Array:
	list.sort_custom(func(a, b): return a["score"] > b["score"])
	return list.slice(0, mini(MAX_ENTRIES, list.size()))

func _check_rollover() -> void:
	var today := _today_string()
	if _last_rollover_date == "":
		# First run ever — nothing to archive yet, just anchor the date.
		_last_rollover_date = today
		_save()
		return
	if today == _last_rollover_date:
		return
	if Time.get_datetime_dict_from_system().hour < ROLLOVER_HOUR:
		return
	_rollover(today)

func _rollover(today: String) -> void:
	_backup_full_store(_last_rollover_date)
	_archive_today(_last_rollover_date)
	entries.clear()
	_last_rollover_date = today
	_save()
	updated.emit()

## "daily disk backup (a con is long — don't lose Day 2)" — a full snapshot
## of both boards as they stood at the end of the outgoing day.
func _backup_full_store(date: String) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)
	var dst := FileAccess.open(ARCHIVE_DIR + date + "_backup.json", FileAccess.WRITE)
	if dst != null:
		dst.store_string(text)

## "Rollover archives the day's board to a dated file before clearing
## today's bucket" — just the outgoing TODAY board, for a quick per-day look.
func _archive_today(date: String) -> void:
	if entries.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)
	var f := FileAccess.open(ARCHIVE_DIR + date + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries))

func _today_string() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_ARRAY:
		entries = data  # legacy (pre-rollover) save format
	elif typeof(data) == TYPE_DICTIONARY:
		entries = data.get("today", [])
		all_time_entries = data.get("all_time", [])
		_last_rollover_date = str(data.get("last_rollover_date", ""))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"today": entries,
			"all_time": all_time_entries,
			"last_rollover_date": _last_rollover_date,
		}))
