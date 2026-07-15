extends Node
class_name HapticSystem
## The TOUCH half of the GDD's "Second Channel". Conveys aim and wind through
## controller rumble so blind / low-vision players can feel what sighted players
## see and others hear.
##
##   * Directional aim guidance — the further off-centre the reticle, the
##     stronger the rumble; the two motors are biased left/right so the pull
##     toward the target has a direction you can feel.
##   * Wind — a constant light rumble proportional to wind speed.
##   * Draw-snap — a sharp pulse the instant full draw is reached (snap()).
##
## Requires a connected gamepad; it no-ops otherwise (keyboard has no motors).

var _accuracy: float = 1.0
var _lateral: float = 0.0
var _refresh: float = 0.0

## Feed each frame with closeness to target (0..1) and side (-1 left..+1 right).
func update(accuracy: float, lateral: float) -> void:
	_accuracy = clampf(accuracy, 0.0, 1.0)
	_lateral = clampf(lateral, -1.0, 1.0)

## A short, strong pulse — used for the full-draw snap.
func snap() -> void:
	var dev := _device()
	if dev >= 0 and AssistSettings.haptics_enabled:
		Input.start_joy_vibration(dev, 0.9, 0.9, 0.12)

## A long, rough rumble — the haptic half of "breath spent, sway rising".
## Longer and heavier than snap() or cancel() so it reads as a warning.
func breath_lost() -> void:
	var dev := _device()
	if dev >= 0 and AssistSettings.haptics_enabled:
		Input.start_joy_vibration(dev, 0.7, 0.25, 0.45)

## A soft low buzz — the haptic half of the "draw cancelled" feedback. Distinct
## from snap() so the two events feel different in the hand.
func cancel() -> void:
	var dev := _device()
	if dev >= 0 and AssistSettings.haptics_enabled:
		Input.start_joy_vibration(dev, 0.0, 0.45, 0.2)

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.1
	var dev := _device()
	if dev < 0 or not AssistSettings.haptics_enabled:
		return

	var off := 1.0 - _accuracy                          # how far from centre
	var wind := Wind.speed_kmh() / maxf(Wind.max_speed_kmh, 0.001)
	# Bias the two motors by which side the target is on, so the rumble has a
	# felt direction; add a steady wind component to both.
	var weak := clampf(off * (0.5 + 0.5 * maxf(_lateral, 0.0)) + wind * 0.15, 0.0, 1.0)
	var strong := clampf(off * (0.5 + 0.5 * maxf(-_lateral, 0.0)) + wind * 0.15, 0.0, 1.0)
	Input.start_joy_vibration(dev, weak, strong, 0.15)

func _device() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if pads.size() > 0 else -1
