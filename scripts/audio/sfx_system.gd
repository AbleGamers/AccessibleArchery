extends Node
class_name SfxSystem
## The game's sound identity, synthesised procedurally — no audio assets, in
## keeping with the zero-asset scaffold. Distinct from AudioCueSystem (which is
## an accessibility instrument): this layer is atmosphere and feedback.
##
##   * Release — a whoosh of decaying noise plus a low string twang.
##   * Impact — a straw thunk; gold-ring hits add a bright two-note ding. Both
##     are PANNED to where the arrow struck the face (left ear = left of
##     centre), so the impact itself tells a blind player which way they missed.
##   * Crowd — an ever-present stadium murmur (filtered noise) that swells into
##     a cheer scaled by the score, and sighs quietly on a miss.
##   * Fanfare — a short arpeggio on match victory (descending on a loss).
##
## Everything is mirrored on the caption channel elsewhere, so nothing here is
## the sole carrier of information. Toggle: AssistSettings.sfx_enabled.
## Runs at 22.05 kHz to keep the per-sample GDScript loop cheap on venue PCs.

const MIX_RATE := 22050.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

var _events: Array[Dictionary] = []   # active one-shots: {kind, t, ...}
var _cheer: float = 0.0               # crowd excitement envelope, decays
var _lpf: float = 0.0                 # crowd noise low-pass state
var _t: float = 0.0                   # global clock (crowd modulation)
var _duck: float = 0.0                # smoothed; 1 = crowd hushed (bow drawn)
var _duck_target: float = 0.0

# Victory / defeat arpeggios (Hz).
const WIN_NOTES: Array[float] = [523.25, 659.25, 783.99, 1046.5]
const LOSE_NOTES: Array[float] = [392.0, 329.63, 261.63]
const NOTE_LEN := 0.18

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

# --- events ---------------------------------------------------------------------

## The arrow leaves the string: whoosh + twang.
func shot_loosed() -> void:
	_events.append({"kind": "whoosh", "t": 0.0})

## A shot resolved with this ring score (0 = miss). Thunk + crowd reaction,
## plus a bright ding for the gold rings. `pan` is where the arrow struck the
## face laterally (-1 left edge .. +1 right edge); the thunk and ding sit there
## in the stereo field. The crowd never pans — it is the room, not the impact.
func arrow_scored(score: int, pan: float = 0.0) -> void:
	if score > 0:
		var p := clampf(pan, -1.0, 1.0)
		_events.append({"kind": "thunk", "t": 0.0, "pan": p})
		_cheer = clampf(_cheer + 0.25 + 0.09 * score, 0.0, 1.6)
		if score >= 9:
			_events.append({"kind": "ding", "t": -0.06, "pan": p})   # slight delay after the thunk
	else:
		_events.append({"kind": "sigh", "t": 0.0})

## 1 = hush the crowd (the bow is drawn). The murmur fades out so the ambience
## never masks the aiming cues during a blindfolded shot — and the arena
## "holding its breath" is exactly the right drama anyway.
func set_duck(amount: float) -> void:
	_duck_target = clampf(amount, 0.0, 1.0)

## Match over: a little arpeggio, rising for a win, falling for a loss.
func match_fanfare(player_won: bool) -> void:
	_events.append({"kind": "fanfare", "t": 0.0, "notes": WIN_NOTES if player_won else LOSE_NOTES})
	if player_won:
		_cheer = 1.6

# --- synthesis --------------------------------------------------------------------

func _process(delta: float) -> void:
	if _playback == null:
		return
	var enabled := AssistSettings.sfx_enabled
	_duck = lerpf(_duck, _duck_target, clampf(6.0 * delta, 0.0, 1.0))
	var dt := 1.0 / MIX_RATE
	for _i in _playback.get_frames_available():
		var frame := Vector2.ZERO
		_t += dt
		_cheer = maxf(_cheer - 0.45 * dt, 0.0)
		if enabled:
			var crowd := _crowd_sample(dt)
			frame += Vector2(crowd, crowd)
			frame += _events_frame(dt)
		_playback.push_frame(frame)
	# Drop finished one-shots.
	_events = _events.filter(func(e): return e["t"] < _event_duration(e))

# Stadium murmur: low-passed noise with a slow breathing modulation, lifted by
# the cheer envelope (which also opens the filter — an excited crowd is
# brighter, not just louder).
func _crowd_sample(_dt: float) -> float:
	var white := randf() * 2.0 - 1.0
	var cutoff := 0.045 + 0.10 * minf(_cheer, 1.0)
	_lpf += (white - _lpf) * cutoff
	var breathing := 1.0 + 0.25 * sin(_t * 0.7) * sin(_t * 0.23)
	var gain := (0.035 + 0.30 * _cheer) * breathing * (1.0 - 0.85 * _duck)
	return _lpf * gain

# One-shots mixed in stereo: events carrying a "pan" (-1..+1, the impact
# sounds) sit there in the field; everything else stays centred. The gain law
# keeps a centred event exactly as loud as the old mono mix.
func _events_frame(dt: float) -> Vector2:
	var frame := Vector2.ZERO
	for e in _events:
		e["t"] += dt
		var t: float = e["t"]
		if t < 0.0:
			continue
		var sample := 0.0
		match e["kind"]:
			"whoosh":
				# Noise burst sweeping down + a 150 Hz string twang.
				sample += (randf() * 2.0 - 1.0) * 0.32 * exp(-t * 16.0)
				sample += sin(TAU * 150.0 * t) * 0.22 * exp(-t * 11.0)
			"thunk":
				# Low thump into the straw boss with a tiny contact click.
				sample += sin(TAU * 85.0 * t) * 0.8 * exp(-t * 20.0)
				if t < 0.012:
					sample += (randf() * 2.0 - 1.0) * 0.35
			"ding":
				sample += (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1318.5 * t)) * 0.16 * exp(-t * 7.0)
			"sigh":
				# The crowd's quiet "aww": a soft, low noise swell.
				var env := sin(clampf(t / 0.5, 0.0, 1.0) * PI)
				sample += _lpf * 0.5 * env
			"fanfare":
				var notes: Array = e["notes"]
				var idx := int(t / NOTE_LEN)
				if idx < notes.size():
					var nt := t - idx * NOTE_LEN
					var freq: float = notes[idx]
					var env := minf(nt / 0.02, 1.0) * exp(-nt * 6.0)
					sample += sin(TAU * freq * nt) * 0.22 * env
					sample += signf(sin(TAU * freq * 0.5 * nt)) * 0.05 * env   # square sub layer
		var pan: float = e.get("pan", 0.0)
		frame += Vector2(sample * clampf(1.0 - pan, 0.0, 1.0), sample * clampf(1.0 + pan, 0.0, 1.0))
	return frame

func _event_duration(e: Dictionary) -> float:
	match e["kind"]:
		"whoosh": return 0.45
		"thunk": return 0.4
		"ding": return 0.8
		"sigh": return 0.55
		"fanfare": return NOTE_LEN * (e["notes"] as Array).size() + 0.3
	return 0.5
