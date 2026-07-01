extends Node
class_name AudioCueSystem
## Sonifies aim, targeting and draw strength so the game is playable without
## sight — the audible half of the GDD's "Second Channel" (win by sight, sound,
## OR touch). The tone is synthesised procedurally, so the scaffold needs no
## audio assets.
##
##   * AIMING — a repeating ping whose PITCH and RATE both rise as the reticle
##     nears dead centre, and whose stereo PAN points toward the target. Faster
##     and higher means you are closing on the bullseye.
##   * DRAWING — a continuous tone whose pitch rises with draw charge.

@export var base_freq: float = 220.0
@export var max_freq: float = 880.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _mix_rate: float = 44100.0
var _phase: float = 0.0
var _clock: float = 0.0          # seconds, drives ping timing

var _active: bool = false        # drawing?
var _aim_x: float = 0.0
var _charge: float = 0.0
var _accuracy: float = 0.0       # 0 = far off, 1 = dead centre
var _lateral: float = 0.0        # -1 target is left, +1 target is right
var _blip_t: float = 0.0         # one-shot "draw cancelled" tone, seconds left

## A short descending tone — the audible half of the "draw cancelled" feedback.
## Plays regardless of the aim-sonification toggle, since it is an event, not a
## continuous cue.
func blip() -> void:
	_blip_t = 0.22

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

## Drive this from ArcheryController.aim_updated (passing whether it is drawing).
func update_cue(aim: Vector2, charge: float, drawing: bool) -> void:
	_aim_x = clampf(aim.x, -1.0, 1.0)
	_charge = clampf(charge, 0.0, 1.0)
	_active = drawing

## Drive this each frame with closeness to the nearest target centre (0..1) and
## which side it is on (-1 left .. +1 right). Powers the centering ping.
func set_targeting(accuracy: float, lateral: float) -> void:
	_accuracy = clampf(accuracy, 0.0, 1.0)
	_lateral = clampf(lateral, -1.0, 1.0)

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var enabled := AssistSettings.audio_cues_enabled
	var dt := 1.0 / _mix_rate
	for _i in _playback.get_frames_available():
		var sample := 0.0
		var pan := _aim_x
		if _blip_t > 0.0:
			# Draw-cancelled blip: a short, centred, descending tone.
			_blip_t -= dt
			var k := clampf(_blip_t / 0.22, 0.0, 1.0)
			var freq := lerpf(150.0, 320.0, k)        # falls as it fades
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.22 * k
			pan = 0.0
		elif enabled and _active:
			# Continuous draw tone: pitch climbs with charge.
			var freq := lerpf(base_freq, max_freq, _charge)
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.20
		elif enabled:
			# Centering ping: pitch and rate both rise toward dead centre.
			var period := lerpf(0.50, 0.06, _accuracy)   # rate: faster near centre
			var freq := lerpf(base_freq, max_freq, _accuracy)  # pitch: higher near centre
			_clock += dt
			var pos := fmod(_clock, period)
			var env := 0.0
			if pos < 0.045:
				env = 0.18 * (1.0 - pos / 0.045)          # short, decaying blip
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * env
			pan = _lateral
		var left := 0.5 * (1.0 - pan)
		var right := 0.5 * (1.0 + pan)
		_playback.push_frame(Vector2(sample * left, sample * right))
