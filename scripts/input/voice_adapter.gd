extends InputAdapter
class_name VoiceAdapter
## Hands-free control by spoken commands.
##
## Godot ships no speech recognizer, so an out-of-process backend recognizes
## speech and feeds command tokens to this adapter over a local UDP socket. The
## reference backend is `tools/voice_bridge.py` (Vosk — offline, open-source).
## Because the recognizer lives in a separate process, the game keeps ZERO
## native dependencies and stays pure GDScript; any recognizer that can send a
## UDP string works, and nothing else in the game changes.
##
## A keyboard DEBUG BRIDGE (active only in the Voice scheme) also lets you test
## the command-to-intent mapping with no microphone:
##   arrows / WASD = nudge aim,  Q = draw,  E = loose,  C = center.

enum Command { AIM_LEFT, AIM_RIGHT, AIM_UP, AIM_DOWN, DRAW, RELEASE, CENTER }

## The speech backend sends one command token per UDP datagram to this port on
## localhost. See tools/voice_bridge.py and docs/VOICE.md.
const BRIDGE_PORT := 9009

@export var nudge_step: float = 0.045   # normalized aim units per command (× sensitivity)

var _pos: Vector2 = Vector2.ZERO
var _was_active: bool = false
var _udp := PacketPeerUDP.new()
var _udp_ready: bool = false

func _init() -> void:
	scheme = AssistSettings.InputScheme.VOICE

func _ready() -> void:
	var err := _udp.bind(BRIDGE_PORT, "127.0.0.1")
	_udp_ready = err == OK
	if not _udp_ready:
		push_warning("VoiceAdapter: could not bind UDP %d — speech bridge disabled (port already in use?)." % BRIDGE_PORT)

## Call this from your speech backend with a recognized Command.
func submit_command(cmd: int) -> void:
	# Scale the per-command nudge by the same sensitivity slider the rate-based
	# devices use, so one setting tunes aim speed across every input method.
	var step := nudge_step * AssistSettings.aim_sensitivity
	match cmd:
		Command.AIM_LEFT:  _pos.x = clampf(_pos.x - step, -1.0, 1.0)
		Command.AIM_RIGHT: _pos.x = clampf(_pos.x + step, -1.0, 1.0)
		Command.AIM_UP:    _pos.y = clampf(_pos.y + step, -1.0, 1.0)
		Command.AIM_DOWN:  _pos.y = clampf(_pos.y - step, -1.0, 1.0)
		Command.CENTER:    _pos = Vector2.ZERO
		Command.DRAW:      InputRouter.report_draw_pressed(self)
		Command.RELEASE:   InputRouter.report_draw_released(self)
	InputRouter.report_aim_absolute(self, _pos)

func _process(_delta: float) -> void:
	if not _is_active():
		_was_active = false
		return
	if not _was_active:
		_pos = Vector2.ZERO
		_was_active = true
	_poll_voice_bridge()
	# Keep reporting current aim so absolute mode holds steady between commands.
	InputRouter.report_aim_absolute(self, _pos)
	_debug_keyboard_bridge()

## Drain any command tokens the speech backend has sent and apply them. Spoken
## words map to tokens by the Python bridge; synonyms are accepted here too.
func _poll_voice_bridge() -> void:
	if not _udp_ready:
		return
	while _udp.get_available_packet_count() > 0:
		var token := _udp.get_packet().get_string_from_utf8().strip_edges().to_upper()
		match token:
			"AIM_LEFT", "LEFT":                 submit_command(Command.AIM_LEFT)
			"AIM_RIGHT", "RIGHT":               submit_command(Command.AIM_RIGHT)
			"AIM_UP", "UP":                     submit_command(Command.AIM_UP)
			"AIM_DOWN", "DOWN":                 submit_command(Command.AIM_DOWN)
			"DRAW", "PULL":                     submit_command(Command.DRAW)
			"RELEASE", "LOOSE", "SHOOT", "FIRE": submit_command(Command.RELEASE)
			"CENTER", "RESET", "MIDDLE":        submit_command(Command.CENTER)

func _debug_keyboard_bridge() -> void:
	if Input.is_action_just_pressed("aim_left"):  submit_command(Command.AIM_LEFT)
	if Input.is_action_just_pressed("aim_right"): submit_command(Command.AIM_RIGHT)
	if Input.is_action_just_pressed("aim_up"):    submit_command(Command.AIM_UP)
	if Input.is_action_just_pressed("aim_down"):  submit_command(Command.AIM_DOWN)
	if Input.is_action_just_pressed("voice_draw"):    submit_command(Command.DRAW)
	if Input.is_action_just_pressed("voice_release"): submit_command(Command.RELEASE)
	if Input.is_action_just_pressed("voice_center"):  submit_command(Command.CENTER)
