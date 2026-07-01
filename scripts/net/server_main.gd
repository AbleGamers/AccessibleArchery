extends Node
## Root of the headless leaderboard server scene (`--server --headless`).
## All the real work happens in the `LeaderboardNet` / `Leaderboard`
## autoloads; this just gives staff terminal visibility that it's alive.

func _ready() -> void:
	print("Accessible Archery — leaderboard server")
	print("Persisted board: %s" % Leaderboard.SAVE_PATH)
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(_print_status)
	add_child(timer)

func _print_status() -> void:
	var peers := multiplayer.get_peers()
	print("LeaderboardNet: %d peer(s) connected, %d entries on the board" % [peers.size(), Leaderboard.entries.size()])
