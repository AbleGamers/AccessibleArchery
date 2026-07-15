extends Node
class_name InputAdapter
## Base class for every device adapter.
##
## An adapter watches ONE kind of device and translates its raw input into the
## abstract archery intents, which it reports to the InputRouter. There are two
## ways to express aim, because devices differ:
##
##   * report_aim_axis(self, v)     — continuous STEERING (rate). The controller
##                                    integrates it over time. Good for keys,
##                                    sticks, "turn left" voice commands.
##   * report_aim_absolute(self, p) — point-to-aim. p is in [-1, 1] for each
##                                    axis and sets aim directly. Good for eye
##                                    tracking, switch scanning, a reticle.
##
## Plus report_draw_pressed(self) / report_draw_released(self).
##
## Gameplay never sees devices — only intents. To support a new device,
## subclass this and register it in InputRouter. Nothing else changes.

## Which AssistSettings.InputScheme this adapter represents. Set in _init().
var scheme: int = -1

## True only while this adapter is the player's selected scheme. Stateful
## adapters should early-out in _process() when this is false.
func _is_active() -> bool:
	return scheme == AssistSettings.input_scheme

## Whether this device can express the optional `steady` (hold-breath) intent.
## Hands-free / low-bandwidth devices return false and the controller steadies
## automatically at full draw for them — never a competitive disadvantage.
func supports_steady() -> bool:
	return false
