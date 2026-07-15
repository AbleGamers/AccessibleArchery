extends Node
class_name AudioCueSystem
## Sonifies aim, targeting and draw strength so the game is playable without
## sight — the audible half of the GDD's "Second Channel" (win by sight, sound,
## OR touch). The tone is synthesised procedurally, so the scaffold needs no
## audio assets.
##
##   * AIMING — a repeating TWO-NOTE ping. The first note's PITCH and RATE rise
##     as the reticle nears dead centre, and the stereo PAN points toward the
##     target (horizontal). The SECOND note encodes VERTICAL error: it sits
##     above the first when you must aim UP, below when you must aim DOWN, and
##     merges into unison when the elevation is right. "Make the two notes one,
##     then follow the pan." Inside the gold cone the ping gains a bright
##     octave shimmer — the audible "locked on".
##   * DRAWING — a continuous tone whose pitch rises with draw charge (and
##     wobbles with sway instability); a distinct two-tone CHIRP marks the
##     instant full draw is reached, so release timing needs no sight.
##   * UI — while a menu captures input (InputRouter.captured_by_ui) the
##     targeting ping goes quiet and the same instrument serves the interface:
##     a PANNED TICK places the highlighted item in the stereo field (pitch
##     rises left→right) and a rising three-note figure confirms a selection.

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
var _vertical: float = 0.0       # -1 aim down .. +1 aim up (elevation error)
var _blip_t: float = 0.0         # one-shot "draw cancelled" tone, seconds left
var _chirp_t: float = 0.0        # one-shot "full draw" chirp, seconds left
var _instability: float = 0.0    # 0 = steady, 1 = sway out of control
var _tick_t: float = 0.0         # one-shot UI browse tick, seconds left
var _tick_pan: float = 0.0
var _tick_freq: float = 440.0
var _confirm_t: float = 0.0      # one-shot UI confirm figure, seconds left

const TICK_LEN := 0.09
const CONFIRM_LEN := 0.30
const CONFIRM_NOTES: Array[float] = [523.25, 659.25, 783.99]

## A short descending tone — the audible half of the "draw cancelled" feedback.
## Plays regardless of the aim-sonification toggle, since it is an event, not a
## continuous cue.
func blip() -> void:
	_blip_t = 0.22

## A quick two-tone rising chirp the instant full draw is reached — the audible
## "you may loose now", so release timing needs no sight.
func full_draw_chirp() -> void:
	_chirp_t = 0.16

## A short panned blip for menu browsing (e.g. the character select): pan
## mirrors WHERE the highlighted item sits on screen and pitch (0..1) rises
## left→right, so sightless browsing has a spatial map, not just spoken names.
## Plays regardless of the aim-sonification toggle — it is an event.
func ui_tick(pan: float, pitch: float) -> void:
	_tick_pan = clampf(pan, -1.0, 1.0)
	_tick_freq = lerpf(330.0, 660.0, clampf(pitch, 0.0, 1.0))
	_tick_t = TICK_LEN

## A rising three-note figure — the audible "selection locked in".
func ui_confirm() -> void:
	_confirm_t = CONFIRM_LEN

func _ready() -> void:
	# Discoverable by UI overlays (same pattern as the "second_channel" group).
	add_to_group("audio_cues")
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

## Drive this each frame with the aim's sway instability (0 steady .. 1 wild).
## The draw tone wobbles with it, so a blind player HEARS the sway build when
## breath runs out — the audible half of the over-hold warning.
func set_instability(v: float) -> void:
	_instability = clampf(v, 0.0, 1.0)

## Drive this each frame with closeness to the nearest target centre (0..1),
## which side it is on (-1 left .. +1 right), and the elevation error
## (-1 aim down .. +1 aim up). Powers the two-note centering ping.
func set_targeting(accuracy: float, lateral: float, vertical: float = 0.0) -> void:
	_accuracy = clampf(accuracy, 0.0, 1.0)
	_lateral = clampf(lateral, -1.0, 1.0)
	_vertical = clampf(vertical, -1.0, 1.0)

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var enabled := AssistSettings.audio_cues_enabled
	var dt := 1.0 / _mix_rate
	for _i in _playback.get_frames_available():
		var sample := 0.0
		var pan := _aim_x
		if _confirm_t > 0.0:
			# UI confirm: three quick rising notes, centred — "locked in".
			_confirm_t -= dt
			var elapsed := CONFIRM_LEN - _confirm_t
			var idx := clampi(int(elapsed / 0.10), 0, CONFIRM_NOTES.size() - 1)
			var nt := elapsed - idx * 0.10
			_phase = fmod(_phase + CONFIRM_NOTES[idx] / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.22 * exp(-nt * 9.0)
			pan = 0.0
		elif _tick_t > 0.0:
			# UI browse tick: a short blip sitting where the highlight sits.
			_tick_t -= dt
			var k := clampf(_tick_t / TICK_LEN, 0.0, 1.0)
			_phase = fmod(_phase + _tick_freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.20 * k
			pan = _tick_pan
		elif _blip_t > 0.0:
			# Draw-cancelled blip: a short, centred, descending tone.
			_blip_t -= dt
			var k := clampf(_blip_t / 0.22, 0.0, 1.0)
			var freq := lerpf(150.0, 320.0, k)        # falls as it fades
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.22 * k
			pan = 0.0
		elif _chirp_t > 0.0:
			# Full-draw chirp: two quick rising tones — "you may loose now".
			_chirp_t -= dt
			var freq := 660.0 if _chirp_t > 0.08 else 990.0
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.24
			pan = 0.0
		elif enabled and _active:
			# Continuous draw tone: pitch climbs with charge, and wobbles (FM)
			# with sway instability so unsteadiness is audible.
			_clock += dt
			var freq := lerpf(base_freq, max_freq, _charge)
			freq *= 1.0 + 0.06 * _instability * sin(_clock * TAU * 7.0)
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * 0.20
		elif enabled and not InputRouter.captured_by_ui:
			# Two-note centering ping: note 1's pitch and rate rise toward dead
			# centre; note 2 encodes elevation error (above = aim up, unison =
			# elevation correct). Near the centre the cadence is too fast for
			# two notes — the fast unison itself says "on line".
			var period := lerpf(0.55, 0.07, _accuracy)
			var freq := lerpf(base_freq, max_freq, _accuracy)
			_clock += dt
			var pos := fmod(_clock, period)
			var env := 0.0
			if pos < 0.045:
				env = 0.20 * (1.0 - pos / 0.045)
			elif period >= 0.20 and pos >= 0.085 and pos < 0.130:
				env = 0.16 * (1.0 - (pos - 0.085) / 0.045)
				freq *= pow(2.0, _vertical * 0.75)
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			sample = sin(_phase * TAU) * env
			if _accuracy >= 0.95:
				sample += sin(_phase * TAU * 2.0) * env * 0.6   # gold-cone shimmer
			pan = _lateral
		var left := 0.5 * (1.0 - pan)
		var right := 0.5 * (1.0 + pan)
		_playback.push_frame(Vector2(sample * left, sample * right))
