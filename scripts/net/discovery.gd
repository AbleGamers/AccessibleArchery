class_name Discovery
extends Node
## Zero-config UDP discovery: the server broadcasts a beacon; stations/display
## listen for it and learn the server's LAN IP. "No IP typing; power-on order
## doesn't matter; a rebooted machine rejoins itself" (see BOOTH_ARCHITECTURE.md).
##
## Not an autoload — `LeaderboardNet` owns one instance and picks
## `start_server_beacon()` or `start_client_listener()` based on `Role.mode`.

signal server_found(ip: String)

var _udp: PacketPeerUDP
var _beacon_timer: Timer
var _poll_timer: Timer

func start_server_beacon() -> void:
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address("255.255.255.255", NetConfig.DISCOVERY_PORT)
	_beacon_timer = Timer.new()
	_beacon_timer.wait_time = NetConfig.DISCOVERY_INTERVAL_SECONDS
	_beacon_timer.autostart = true
	_beacon_timer.timeout.connect(_send_beacon)
	add_child(_beacon_timer)
	_send_beacon()

func start_client_listener() -> void:
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(NetConfig.DISCOVERY_PORT)
	if err != OK:
		push_warning("Discovery: failed to bind UDP %d (%s) — manual --ip= required" % [NetConfig.DISCOVERY_PORT, err])
		return
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.25
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)

func stop() -> void:
	if _beacon_timer != null:
		_beacon_timer.stop()
	if _poll_timer != null:
		_poll_timer.stop()
	if _udp != null:
		_udp.close()

func _send_beacon() -> void:
	var payload := JSON.stringify({
		"service": NetConfig.DISCOVERY_SERVICE,
		"port": NetConfig.PORT,
		"name": "Booth",
	})
	_udp.put_packet(payload.to_utf8_buffer())

func _poll() -> void:
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var sender_ip := _udp.get_packet_ip()
		var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.get("service") == NetConfig.DISCOVERY_SERVICE:
			server_found.emit(sender_ip)
