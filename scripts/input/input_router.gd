extends Node
## Device-agnostic input hub — the architectural heart of the project.
##
## Raw devices never talk to gameplay directly. Each device has an InputAdapter
## that translates its input into intents:
##     * aim_axis     — continuous steering (rate), integrated by the controller
##     * aim_absolute — point-to-aim, in [-1, 1] per axis
##     * draw         — begin pulling the string
##     * release      — loose the arrow
##
## Gameplay listens to the signals below and is therefore IDENTICAL whether the
## player uses a keyboard, a gamepad, a single switch, an Xbox Adaptive
## Controller, eye-tracking, voice, or a future community-contributed adapter.
##
## Autoloaded as `InputRouter`.

signal aim_axis(axis: Vector2)
signal aim_absolute(position: Vector2)
signal draw_pressed
signal draw_released

var _adapters: Array[InputAdapter] = []

func _ready() -> void:
	_register_default_actions()
	# Built-in adapters. Community device support is added simply by writing a
	# new InputAdapter subclass and registering it here (or via a plugin).
	register_adapter(KeyboardMouseAdapter.new())
	register_adapter(GamepadAdapter.new())
	register_adapter(SingleSwitchAdapter.new())
	register_adapter(EyeTrackingAdapter.new())
	register_adapter(VoiceAdapter.new())

func _process(_delta: float) -> void:
	# Let the player hot-swap the active device. In a shipping build this lives
	# in an accessibility menu; here it is on number keys for quick testing.
	if Input.is_action_just_pressed("scheme_keyboard"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.KEYBOARD_MOUSE)
	elif Input.is_action_just_pressed("scheme_gamepad"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.GAMEPAD)
	elif Input.is_action_just_pressed("scheme_switch"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.SINGLE_SWITCH)
	elif Input.is_action_just_pressed("scheme_eye"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.EYE_TRACKING)
	elif Input.is_action_just_pressed("scheme_voice"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.VOICE)

func register_adapter(adapter: InputAdapter) -> void:
	_adapters.append(adapter)
	add_child(adapter)

# --- Adapters report intents through these. The router forwards them only if
# --- the reporting adapter matches the currently-active scheme. ---------------

func report_aim_axis(adapter: InputAdapter, axis: Vector2) -> void:
	if _is_active(adapter):
		aim_axis.emit(axis)

func report_aim_absolute(adapter: InputAdapter, position: Vector2) -> void:
	if _is_active(adapter):
		aim_absolute.emit(position)

func report_draw_pressed(adapter: InputAdapter) -> void:
	if _is_active(adapter):
		draw_pressed.emit()

func report_draw_released(adapter: InputAdapter) -> void:
	if _is_active(adapter):
		draw_released.emit()

func _is_active(adapter: InputAdapter) -> bool:
	return adapter.scheme == AssistSettings.input_scheme

# --- Input actions are registered in code (not in project.godot) so the whole
# --- input map is visible and documented in one place. Remapping these is
# --- itself an accessibility feature. ----------------------------------------

func _register_default_actions() -> void:
	_add_key_action("draw", [KEY_SPACE, KEY_ENTER])
	_add_key_action("aim_left", [KEY_LEFT, KEY_A])
	_add_key_action("aim_right", [KEY_RIGHT, KEY_D])
	_add_key_action("aim_up", [KEY_UP, KEY_W])
	_add_key_action("aim_down", [KEY_DOWN, KEY_S])
	_add_key_action("scheme_keyboard", [KEY_1])
	_add_key_action("scheme_gamepad", [KEY_2])
	_add_key_action("scheme_switch", [KEY_3])
	_add_key_action("scheme_eye", [KEY_4])
	_add_key_action("scheme_voice", [KEY_5])
	# Voice debug bridge (test the command mapping with no microphone).
	_add_key_action("voice_draw", [KEY_Q])
	_add_key_action("voice_release", [KEY_E])
	_add_key_action("voice_center", [KEY_C])
	# Gamepad. An Xbox Adaptive Controller enumerates as a standard gamepad, so
	# these bindings serve it for free.
	_add_joy_button_action("draw_pad", JOY_BUTTON_A)
	_add_joy_axis_action("pad_aim_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("pad_aim_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("pad_aim_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("pad_aim_down", JOY_AXIS_LEFT_Y, 1.0)

func _add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _add_joy_button_action(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy_axis_action(action: StringName, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
