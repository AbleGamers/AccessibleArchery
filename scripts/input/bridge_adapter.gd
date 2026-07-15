extends InputAdapter
class_name BridgeAdapter
## The AT BRIDGE — a universal connector for assistive interfaces the game has
## never heard of. Any external program that can read a device (a BCI rig, an
## EMG band, an Arduino sip-and-puff sensor, a head tracker, a smartphone app…)
## connects by sending one-line text commands over local UDP; this adapter
## translates them into the standard intents. The full protocol is documented
## in docs/AT_BRIDGE.md and a runnable reference client is
## tools/at_bridge_demo.py — a new device is ~20 lines of any language.
##
## Same pattern as the voice bridge: the device code lives out of process, the
## game keeps zero native dependencies, and nothing in gameplay changes.

## One command per UDP datagram, plain text, to this port on localhost:
##   AIM x y        — absolute aim, each in [-1, 1]      (point-to-aim devices)
##   AIM_AXIS x y   — rate steering, each in [-1, 1]; send 0 0 to stop
##   NUDGE_LEFT / NUDGE_RIGHT / NUDGE_UP / NUDGE_DOWN — stepped absolute aim
##   CENTER         — recentre the aim
##   DRAW           — begin the draw
##   RELEASE        — loose (also: LOOSE, FIRE, SHOOT)
##   STEADY         — hold breath (manual steady)        UNSTEADY — let it go
const BRIDGE_PORT := 9010

## Per-NUDGE step, scaled by the shared sensitivity setting like every other
## stepped device (voice uses the same value).
@export var nudge_step: float = 0.045

var _pos: Vector2 = Vector2.ZERO
var _udp := PacketPeerUDP.new()
var _udp_ready: bool = false
var _was_active: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.BRIDGE

func supports_steady() -> bool:
	return true   # the protocol has STEADY / UNSTEADY

func _ready() -> void:
	var err := _udp.bind(BRIDGE_PORT, "127.0.0.1")
	_udp_ready = err == OK
	if not _udp_ready:
		push_warning("BridgeAdapter: could not bind UDP %d — AT bridge disabled (port already in use?)." % BRIDGE_PORT)

func _process(_delta: float) -> void:
	if not _udp_ready:
		return
	if not _is_active():
		_was_active = false
		# Drain silently so stale packets don't fire the moment we activate.
		while _udp.get_available_packet_count() > 0:
			_udp.get_packet()
		return
	if not _was_active:
		_pos = Vector2.ZERO
		_was_active = true
	while _udp.get_available_packet_count() > 0:
		_handle(_udp.get_packet().get_string_from_utf8())

func _handle(line: String) -> void:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	match parts[0].to_upper():
		"AIM":
			if parts.size() >= 3:
				_pos = Vector2(clampf(float(parts[1]), -1.0, 1.0), clampf(float(parts[2]), -1.0, 1.0))
				InputRouter.report_aim_absolute(self, _pos)
		"AIM_AXIS":
			if parts.size() >= 3:
				InputRouter.report_aim_axis(self, Vector2(
					clampf(float(parts[1]), -1.0, 1.0), clampf(float(parts[2]), -1.0, 1.0)))
		"NUDGE_LEFT":  _nudge(Vector2(-1, 0))
		"NUDGE_RIGHT": _nudge(Vector2(1, 0))
		"NUDGE_UP":    _nudge(Vector2(0, 1))
		"NUDGE_DOWN":  _nudge(Vector2(0, -1))
		"CENTER", "CENTRE", "RESET":
			_pos = Vector2.ZERO
			InputRouter.report_aim_absolute(self, _pos)
		"DRAW", "PULL":
			InputRouter.report_draw_pressed(self)
		"RELEASE", "LOOSE", "FIRE", "SHOOT":
			InputRouter.report_draw_released(self)
		"STEADY", "HOLD":
			InputRouter.report_steady_pressed(self)
		"UNSTEADY", "BREATHE":
			InputRouter.report_steady_released(self)

func _nudge(dir: Vector2) -> void:
	var step := nudge_step * AssistSettings.aim_sensitivity
	_pos = (_pos + dir * step).clamp(Vector2(-1, -1), Vector2(1, 1))
	InputRouter.report_aim_absolute(self, _pos)
