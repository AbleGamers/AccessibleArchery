extends Node
class_name AudioCueSystem
## Sonifies aim, targeting and draw strength so the game is playable without
## sight — the audible half of the GDD's "Second Channel" (win by sight, sound,
## OR touch). The tone is synthesised procedurally, so the scaffold needs no
## audio assets.
##
##   * AIMING — the horizontal and vertical guidance are SEPARATED IN TIME so a
##     player never decodes two things at once:
##       - HORIZONTAL beat: a single note, PANNED toward the target, whose PITCH
##         and RATE rise as the reticle nears dead centre. Inside the gold cone
##         it gains a bright octave shimmer — the audible "locked on". Steer
##         toward the sound and close in until it is fast and centred.
##       - VERTICAL beat: only while the elevation is off, a CENTRED pair of
##         notes alternates in between the horizontal beats — a fixed reference
##         note then a second note ABOVE it when you must aim up, BELOW when you
##         must aim down, unison when level. "Rising pair = up, falling = down."
##         When your elevation is right these beats simply stop.
##     All tone shaping (pitch range, tempo, guidance cone, pan strength, the
##     elevation interval, whether the vertical beat plays at all) is read live
##     from AssistSettings, so the player tunes the feel from the options menu.
##   * DRAWING — a continuous tone whose pitch rises with draw charge (and
##     wobbles with sway instability); a distinct two-tone CHIRP marks the
##     instant full draw is reached, so release timing needs no sight. The
##     centering ping keeps running QUIETLY underneath the draw tone, so drift
##     off the gold is audible before the release — and the tone itself gains
##     the octave shimmer while the aim is inside the gold cone ("loose now").
##   * STEADY — while held breath keeps the aim locked, a soft METRONOME tick
##     counts the release window down: the ticks speed up and rise in pitch as
##     breath runs out, so the release can be timed by ear alone.
##   * UI — while a menu captures input (InputRouter.captured_by_ui) the
##     targeting ping goes quiet and the same instrument serves the interface:
##     a PANNED TICK places the highlighted item in the stereo field (pitch
##     rises left→right) and a rising three-note figure confirms a selection.

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _mix_rate: float = 44100.0
var _phase: float = 0.0          # oscillator for the ping + one-shot events
var _phase_draw: float = 0.0     # oscillator for the draw tone (mixed with ping)
var _phase_beat: float = 0.0     # oscillator for the steady-breath metronome
var _clock: float = 0.0          # seconds, drives the draw-tone wobble
var _beat_clock: float = 0.0     # seconds, drives metronome timing

# Ping beat state: aim guidance alternates a panned HORIZONTAL beat and (only
# when elevation is off) a centred VERTICAL beat, so the two axes never sound at
# the same instant.
var _ping_t: float = 0.0         # seconds into the current beat
var _ping_dur: float = 0.0       # current beat's length (0 = pick a new one)
var _ping_vertical: bool = false # is the current beat the elevation beat?
var _vert_turn: bool = false     # alternation toggle while elevation is off

var _active: bool = false        # drawing?
var _charge: float = 0.0
var _accuracy: float = 0.0       # 0 = far off, 1 = dead centre
var _lateral: float = 0.0        # -1 target is left, +1 target is right
var _vertical: float = 0.0       # -1 aim down .. +1 aim up (elevation error)
var _blip_t: float = 0.0         # one-shot "draw cancelled" tone, seconds left
var _chirp_t: float = 0.0        # one-shot "full draw" chirp, seconds left
var _instability: float = 0.0    # 0 = steady, 1 = sway out of control
var _breath_frac: float = 1.0    # remaining held-breath fraction (1 = full)
var _steady: bool = false        # held breath is currently locking the aim
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
func update_cue(_aim: Vector2, charge: float, drawing: bool) -> void:
	_charge = clampf(charge, 0.0, 1.0)
	_active = drawing

## Drive this each frame with the aim's sway instability (0 steady .. 1 wild).
## The draw tone wobbles with it, so a blind player HEARS the sway build when
## breath runs out — the audible half of the over-hold warning.
func set_instability(v: float) -> void:
	_instability = clampf(v, 0.0, 1.0)

## Drive this each frame with closeness to the nearest target centre (0..1),
## which side it is on (-1 left .. +1 right), and the elevation error
## (-1 aim down .. +1 aim up). Powers the panned horizontal ping and the
## time-separated centred elevation beat.
func set_targeting(accuracy: float, lateral: float, vertical: float = 0.0) -> void:
	_accuracy = clampf(accuracy, 0.0, 1.0)
	_lateral = clampf(lateral, -1.0, 1.0)
	_vertical = clampf(vertical, -1.0, 1.0)

## Drive this each frame with the remaining held-breath fraction (1 = full) and
## whether the steady hold is active. While steady, a soft metronome tick counts
## the release window down — rate and pitch rise as breath runs out — so a blind
## player can time the release instead of waiting for the spoken warning.
func set_breath(fraction: float, steady: bool) -> void:
	_breath_frac = clampf(fraction, 0.0, 1.0)
	if steady != _steady:
		_steady = steady
		_beat_clock = 0.0

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var enabled := AssistSettings.audio_cues_enabled
	var dt := 1.0 / _mix_rate
	for _i in _playback.get_frames_available():
		var frame := Vector2.ZERO
		if _confirm_t > 0.0:
			# UI confirm: three quick rising notes, centred — "locked in".
			_confirm_t -= dt
			var elapsed := CONFIRM_LEN - _confirm_t
			var idx := clampi(int(elapsed / 0.10), 0, CONFIRM_NOTES.size() - 1)
			var nt := elapsed - idx * 0.10
			_phase = fmod(_phase + CONFIRM_NOTES[idx] / _mix_rate, 1.0)
			frame = _panned(sin(_phase * TAU) * 0.22 * exp(-nt * 9.0), 0.0)
		elif _tick_t > 0.0:
			# UI browse tick: a short blip sitting where the highlight sits.
			_tick_t -= dt
			var k := clampf(_tick_t / TICK_LEN, 0.0, 1.0)
			_phase = fmod(_phase + _tick_freq / _mix_rate, 1.0)
			frame = _panned(sin(_phase * TAU) * 0.20 * k, _tick_pan)
		elif _blip_t > 0.0:
			# Draw-cancelled blip: a short, centred, descending tone.
			_blip_t -= dt
			var k := clampf(_blip_t / 0.22, 0.0, 1.0)
			var freq := lerpf(150.0, 320.0, k)        # falls as it fades
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			frame = _panned(sin(_phase * TAU) * 0.22 * k, 0.0)
		elif _chirp_t > 0.0:
			# Full-draw chirp: two quick rising tones — "you may loose now".
			_chirp_t -= dt
			var freq := 660.0 if _chirp_t > 0.08 else 990.0
			_phase = fmod(_phase + freq / _mix_rate, 1.0)
			frame = _panned(sin(_phase * TAU) * 0.24, 0.0)
		elif enabled and not InputRouter.captured_by_ui:
			_clock += dt
			# Aim guidance, SEPARATED IN TIME: a panned horizontal beat, then
			# (only while elevation is off) a centred vertical beat in between —
			# so the player never decodes left/right and up/down at once. While
			# DRAWING the ping keeps running (at AssistSettings.aim_cue_while_
			# drawing) under the draw tone, so drift off the gold stays audible.
			_ping_t += dt
			if _ping_dur <= 0.0 or _ping_t >= _ping_dur:
				_ping_t = 0.0
				_advance_beat()
			var ping := 0.0
			var ping_pan := 0.0
			if _ping_vertical:
				# Elevation beat: a fixed reference note, then a note above it to
				# aim UP / below to aim DOWN (unison = level). Centred, so its lack
				# of pan marks it out from the steering beat.
				var lo := AssistSettings.cue_pitch_low
				var vfreq := lo
				var venv := 0.0
				if _ping_t < 0.045:
					venv = 0.18 * (1.0 - _ping_t / 0.045)
				elif _ping_t >= 0.065 and _ping_t < 0.120:
					venv = 0.18 * (1.0 - (_ping_t - 0.065) / 0.055)
					vfreq = lo * pow(2.0, _vertical * AssistSettings.elevation_interval)
				_phase = fmod(_phase + vfreq / _mix_rate, 1.0)
				ping = sin(_phase * TAU) * venv
			else:
				# Horizontal beat: one note, panned to the target side, pitch
				# rising with closeness; the gap after it encodes the rate. Inside
				# the gold cone it gains the octave shimmer — "locked on".
				var hfreq := lerpf(AssistSettings.cue_pitch_low, AssistSettings.cue_pitch_high, _accuracy)
				var henv := 0.0
				if _ping_t < 0.045:
					henv = 0.20 * (1.0 - _ping_t / 0.045)
				_phase = fmod(_phase + hfreq / _mix_rate, 1.0)
				ping = sin(_phase * TAU) * henv
				if _accuracy >= 0.95:
					ping += sin(_phase * TAU * 2.0) * henv * 0.6
				ping_pan = _lateral
			frame = _panned(ping * (AssistSettings.aim_cue_while_drawing if _active else 1.0), ping_pan)
			if _active:
				# Continuous draw tone, centred: pitch climbs with charge and
				# wobbles (FM) with sway instability so unsteadiness is audible.
				# Inside the gold cone it gains the octave shimmer — the same
				# "locked on" colour as the ping, heard without letting go.
				var dfreq := lerpf(AssistSettings.cue_pitch_low, AssistSettings.cue_pitch_high, _charge)
				dfreq *= 1.0 + 0.06 * _instability * sin(_clock * TAU * 7.0)
				_phase_draw = fmod(_phase_draw + dfreq / _mix_rate, 1.0)
				var tone := sin(_phase_draw * TAU) * 0.16
				if _accuracy >= 0.95:
					tone += sin(_phase_draw * TAU * 2.0) * 0.09
				frame += _panned(tone, 0.0)
				if _steady:
					# Steady-breath metronome: soft high ticks that speed up and
					# rise as the held breath runs out — the audible countdown
					# of the release window.
					_beat_clock += dt
					var urgency := 1.0 - _breath_frac
					var beat_period := lerpf(0.55, 0.14, urgency)
					var bpos := fmod(_beat_clock, beat_period)
					if bpos < 0.030:
						var bfreq := lerpf(1046.5, 1568.0, urgency)   # C6 → G6
						_phase_beat = fmod(_phase_beat + bfreq / _mix_rate, 1.0)
						frame += _panned(sin(_phase_beat * TAU) * 0.12 * AssistSettings.breath_tick_volume * (1.0 - bpos / 0.030), 0.0)
		_playback.push_frame(frame * AssistSettings.cue_volume)

# Chooses the next ping beat. When the elevation is off (and the elevation cue
# is on), horizontal and vertical beats ALTERNATE, so up/down never overlaps
# left/right; when elevation is level (or the cue is off) every beat is the
# panned horizontal one. The horizontal cadence shrinks with closeness (rate =
# "how close"); a vertical beat is stretched to a floor so its two notes always
# fit. AssistSettings.cue_tempo scales the whole cadence.
func _advance_beat() -> void:
	var period := lerpf(0.55, 0.07, _accuracy) / maxf(AssistSettings.cue_tempo, 0.05)
	var want_vertical := AssistSettings.elevation_cue_enabled and absf(_vertical) > 0.15
	if want_vertical:
		_vert_turn = not _vert_turn
		_ping_vertical = _vert_turn
	else:
		_ping_vertical = false
	_ping_dur = maxf(period, 0.20) if _ping_vertical else period

# Equal-gain stereo placement for one mono sample (pan -1 left .. +1 right).
func _panned(sample: float, pan: float) -> Vector2:
	return Vector2(sample * 0.5 * (1.0 - pan), sample * 0.5 * (1.0 + pan))
