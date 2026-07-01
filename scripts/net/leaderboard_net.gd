extends Node
## Autoload `LeaderboardNet`. The network transport for the booth leaderboard.
##
## Deliberately separate from `Leaderboard` (the store): this node's only job
## is moving scores between machines over ENet high-level multiplayer,
## dedicated-server model. `Leaderboard`'s API (add_score/top/updated) is
## unchanged so main.gd and the existing scoreboard scripts don't care
## whether a run is networked.
##
## Works for all three roles because autoloads sit at the same `/root/...`
## NodePath on every peer, which is what Godot RPC dispatch matches on.

signal updated(today: Array, all_time: Array)
signal connection_state_changed(is_connected: bool)

const OUTBOX_PATH := "user://leaderboard_outbox.json"

var _peer: ENetMultiplayerPeer
var _connected := false
var _discovery: Discovery
var _discovery_timeout: Timer
var _reconnect_timer: Timer
var _client_signals_connected := false

## Offline outbox: scores banked while disconnected queue here, persisted to
## disk so a station reboot mid-outage doesn't lose them, and flush once
## connected. Each entry gets a locally-unique `id`; the server acks by id
## once it's actually stored, so an entry is only dropped from the outbox
## after it's confirmed on the board — a dropped connection mid-send just
## means it gets resent next flush.
var _outbox: Array = []
var _next_outbox_id := 0

func _ready() -> void:
	_load_outbox()
	match Role.mode:
		Role.Mode.SERVER:
			_start_server()
			_discovery = Discovery.new()
			add_child(_discovery)
			_discovery.start_server_beacon()
		Role.Mode.STATION, Role.Mode.DISPLAY:
			if Role.ip_overridden:
				_start_client()
			else:
				_start_discovery_then_client()

func is_connected_to_server() -> bool:
	return _connected

## Stations call this after banking a score. Always queues to the (persisted)
## outbox first, then tries to send immediately if connected — so a score is
## never lost even if the network drops mid-submit.
func submit(player_name: String, score: int, input_scheme: int, station_name: String) -> void:
	if Role.mode == Role.Mode.SERVER:
		return
	_next_outbox_id += 1
	var entry := {
		"id": _next_outbox_id,
		"name": player_name,
		"score": score,
		"input": input_scheme,
		"station": station_name,
	}
	_outbox.append(entry)
	_save_outbox()
	_try_send(entry)

func _try_send(entry: Dictionary) -> void:
	if not _connected:
		return
	submit_score.rpc_id(1, entry["id"], entry["name"], entry["score"], entry["input"], entry["station"])

func _flush_outbox() -> void:
	for e in _outbox:
		_try_send(e)

func _start_server() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(NetConfig.PORT, NetConfig.MAX_PEERS)
	if err != OK:
		push_error("LeaderboardNet: failed to start server on port %d (%s)" % [NetConfig.PORT, err])
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	# Broadcast on ANY store change, not just network submissions — this is
	# what covers a rollover (see leaderboard_store.gd) reaching the display
	# even though nobody submitted a score at 6am.
	Leaderboard.updated.connect(_broadcast)
	print("LeaderboardNet: server listening on port %d" % NetConfig.PORT)

func _broadcast() -> void:
	leaderboard_updated.rpc(Leaderboard.top(), Leaderboard.top_all_time())

## No manual --ip=: listen for the server's beacon and connect to whichever
## address it comes from. Falls back to Role.server_ip's default (127.0.0.1)
## if nothing is heard within DISCOVERY_TIMEOUT_SECONDS (broadcast blocked,
## or this is a single-machine dev test).
func _start_discovery_then_client() -> void:
	_discovery = Discovery.new()
	add_child(_discovery)
	_discovery.server_found.connect(_on_server_found)
	_discovery.start_client_listener()

	_discovery_timeout = Timer.new()
	_discovery_timeout.wait_time = NetConfig.DISCOVERY_TIMEOUT_SECONDS
	_discovery_timeout.one_shot = true
	_discovery_timeout.timeout.connect(func(): _on_server_found(Role.server_ip))
	add_child(_discovery_timeout)
	_discovery_timeout.start()

func _on_server_found(ip: String) -> void:
	if _peer != null:
		return  # already connecting/connected — ignore late/duplicate beacons
	_discovery_timeout.stop()
	Role.server_ip = ip
	_start_client()

func _start_client() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(Role.server_ip, NetConfig.PORT)
	if err != OK:
		push_error("LeaderboardNet: failed to start client to %s:%d (%s)" % [Role.server_ip, NetConfig.PORT, err])
		return
	multiplayer.multiplayer_peer = _peer
	# `multiplayer` is the SceneTree's MultiplayerAPI — it outlives any one
	# peer, so these only need connecting once even across many reconnects.
	if not _client_signals_connected:
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_disconnected)
		multiplayer.server_disconnected.connect(_on_disconnected)
		_client_signals_connected = true

func _on_connected() -> void:
	_connected = true
	# Flush BEFORE emitting: if a `connection_state_changed` listener reacts
	# by calling submit() synchronously, that new entry must not also be
	# swept up by this flush and sent twice.
	_flush_outbox()
	connection_state_changed.emit(true)

func _on_disconnected() -> void:
	_connected = false
	_peer = null
	connection_state_changed.emit(false)
	_schedule_reconnect()

## Retries forever, every RECONNECT_INTERVAL_SECONDS, with no staff
## intervention — a booth machine that loses WiFi/gets rebooted just rejoins
## once it's back. Reuses the last known Role.server_ip rather than
## re-running discovery (the server's IP won't have changed mid-event).
func _schedule_reconnect() -> void:
	if _reconnect_timer != null:
		return
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = NetConfig.RECONNECT_INTERVAL_SECONDS
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_attempt_reconnect)
	add_child(_reconnect_timer)
	_reconnect_timer.start()

func _attempt_reconnect() -> void:
	_reconnect_timer.queue_free()
	_reconnect_timer = null
	_start_client()

func _on_peer_connected(id: int) -> void:
	# Late joiner: give it the current board without waiting for the next score.
	leaderboard_updated.rpc_id(id, Leaderboard.top(), Leaderboard.top_all_time())

@rpc("any_peer", "reliable")
func submit_score(entry_id: int, player_name: String, score: int, input_scheme: int, station_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if score < 0 or score > NetConfig.MAX_PLAUSIBLE_SCORE:
		return
	Leaderboard.add_score(_sanitize_name(player_name), score, input_scheme, station_name)  # emits updated -> _broadcast()
	submit_ack.rpc_id(sender_id, entry_id)

@rpc("authority", "reliable")
func leaderboard_updated(today: Array, all_time: Array) -> void:
	if Role.mode == Role.Mode.SERVER:
		return
	updated.emit(today, all_time)

@rpc("authority", "reliable")
func submit_ack(entry_id: int) -> void:
	if Role.mode == Role.Mode.SERVER:
		return
	_outbox = _outbox.filter(func(e): return e["id"] != entry_id)
	_save_outbox()

func _sanitize_name(raw: String) -> String:
	var n := raw.strip_edges()
	if n.length() > NetConfig.MAX_NAME_LEN:
		n = n.substr(0, NetConfig.MAX_NAME_LEN)
	if n.is_empty():
		n = "Player"
	var lower := n.to_lower()
	for bad in NetConfig.PROFANITY_BLOCKLIST:
		if lower.contains(bad):
			n = "*".repeat(n.length())
			break
	return n

func _load_outbox() -> void:
	if not FileAccess.file_exists(OUTBOX_PATH):
		return
	var f := FileAccess.open(OUTBOX_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		return
	_outbox = data
	for e in _outbox:
		_next_outbox_id = maxi(_next_outbox_id, int(e.get("id", 0)))

func _save_outbox() -> void:
	var f := FileAccess.open(OUTBOX_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_outbox))
