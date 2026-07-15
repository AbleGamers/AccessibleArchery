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
## Optional intent: hold breath to steady the aim at full draw. Only some
## devices can express it (see InputAdapter.supports_steady()); schemes that
## can't get auto-hold behaviour from the controller instead, so no device is
## disadvantaged.
signal steady_pressed
signal steady_released

var _adapters: Array[InputAdapter] = []

## While true, an accessible UI overlay (e.g. the character select) is consuming
## the intents: gameplay must ignore them. The overlay listens to the SAME
## signals, so every device navigates the UI exactly the way it plays the game.
var captured_by_ui: bool = false

func _ready() -> void:
	_register_default_actions()
	_apply_overrides()   # player rebinds, persisted by AssistSettings
	# Built-in adapters. Community device support is added simply by writing a
	# new InputAdapter subclass and registering it here (or via a plugin).
	register_adapter(KeyboardMouseAdapter.new())
	register_adapter(GamepadAdapter.new())
	register_adapter(SingleSwitchAdapter.new())
	register_adapter(EyeTrackingAdapter.new())
	register_adapter(VoiceAdapter.new())
	register_adapter(BridgeAdapter.new())

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
	elif Input.is_action_just_pressed("scheme_bridge"):
		AssistSettings.set_input_scheme(AssistSettings.InputScheme.BRIDGE)

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

func report_steady_pressed(adapter: InputAdapter) -> void:
	if _is_active(adapter):
		steady_pressed.emit()

func report_steady_released(adapter: InputAdapter) -> void:
	if _is_active(adapter):
		steady_released.emit()

## Whether the ACTIVE scheme's adapter can express the steady intent at all.
## Gameplay uses this to fall back to auto-hold for hands-free devices.
func steady_supported() -> bool:
	for adapter in _adapters:
		if adapter.scheme == AssistSettings.input_scheme:
			return adapter.supports_steady()
	return false

func _is_active(adapter: InputAdapter) -> bool:
	return adapter.scheme == AssistSettings.input_scheme

# --- Input actions are registered in code (not in project.godot) so the whole
# --- input map is visible and documented in one place. Remapping these is
# --- itself an accessibility feature. ----------------------------------------

func _register_default_actions() -> void:
	# Remappable actions come from one defaults table so the remapping UI's
	# "reset to defaults" can never drift from what ships.
	for action: StringName in REMAPPABLE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev in _default_events(action):
			InputMap.action_add_event(action, ev)
	_add_key_action("scheme_keyboard", [KEY_1])
	_add_key_action("scheme_gamepad", [KEY_2])
	_add_key_action("scheme_switch", [KEY_3])
	_add_key_action("scheme_eye", [KEY_4])
	_add_key_action("scheme_voice", [KEY_5])
	_add_key_action("scheme_bridge", [KEY_6])
	# Voice debug bridge (test the command mapping with no microphone).
	_add_key_action("voice_draw", [KEY_Q])
	_add_key_action("voice_release", [KEY_E])
	_add_key_action("voice_center", [KEY_C])
	# Gamepad. An Xbox Adaptive Controller enumerates as a standard gamepad, so
	# these bindings serve it for free.
	_add_joy_axis_action("pad_aim_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("pad_aim_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("pad_aim_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("pad_aim_down", JOY_AXIS_LEFT_Y, 1.0)

# --- Runtime remapping ---------------------------------------------------------
# Rebinding is itself an accessibility feature: a lot of assistive hardware
# enumerates as "a keyboard that only types one unusual key" or "a gamepad with
# one button". The Controls page of the options menu drives these.

## Actions the player may rebind (action -> label shown in the Controls UI).
const REMAPPABLE := {
	&"draw": "Draw / switch",
	&"steady": "Steady (hold breath)",
	&"aim_left": "Aim left",
	&"aim_right": "Aim right",
	&"aim_up": "Aim up",
	&"aim_down": "Aim down",
	&"draw_pad": "Draw (gamepad)",
	&"steady_pad": "Steady (gamepad)",
}

## Replace an action's bindings with one captured event (normalized so stray
## modifiers / partial axis values are not baked in) and persist the override.
func rebind(action: StringName, event: InputEvent) -> void:
	if not REMAPPABLE.has(action):
		return
	var clean := _normalize_event(event)
	if clean == null:
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, clean)
	AssistSettings.input_overrides[String(action)] = _serialize_event(clean)
	AssistSettings.request_save()

## Restore every remappable action to its shipped defaults.
func reset_bindings() -> void:
	AssistSettings.input_overrides.clear()
	AssistSettings.request_save()
	for action: StringName in REMAPPABLE:
		InputMap.action_erase_events(action)
		for ev in _default_events(action):
			InputMap.action_add_event(action, ev)

## Human-readable summary of an action's current bindings, for the Controls UI.
func binding_label(action: StringName) -> String:
	var parts := PackedStringArray()
	for ev in InputMap.action_get_events(action):
		parts.append(_event_label(ev))
	return " / ".join(parts) if parts.size() > 0 else "—"

func _apply_overrides() -> void:
	for action_name: String in AssistSettings.input_overrides:
		var action := StringName(action_name)
		if not REMAPPABLE.has(action) or not InputMap.has_action(action):
			continue
		var ev := _deserialize_event(AssistSettings.input_overrides[action_name])
		if ev != null:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)

func _default_events(action: StringName) -> Array[InputEvent]:
	match action:
		&"draw":       return [_key_ev(KEY_SPACE), _key_ev(KEY_ENTER)]
		&"steady":     return [_key_ev(KEY_SHIFT)]
		&"aim_left":   return [_key_ev(KEY_LEFT), _key_ev(KEY_A)]
		&"aim_right":  return [_key_ev(KEY_RIGHT), _key_ev(KEY_D)]
		&"aim_up":     return [_key_ev(KEY_UP), _key_ev(KEY_W)]
		&"aim_down":   return [_key_ev(KEY_DOWN), _key_ev(KEY_S)]
		&"draw_pad":   return [_joy_btn_ev(JOY_BUTTON_A)]
		&"steady_pad": return [_joy_btn_ev(JOY_BUTTON_X)]
	return []

func _normalize_event(ev: InputEvent) -> InputEvent:
	if ev is InputEventKey:
		return _key_ev(ev.physical_keycode)
	if ev is InputEventJoypadButton:
		return _joy_btn_ev(ev.button_index)
	if ev is InputEventJoypadMotion:
		var m := InputEventJoypadMotion.new()
		m.axis = ev.axis
		m.axis_value = signf(ev.axis_value)
		return m
	return null

func _serialize_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"kind": "key", "code": int(ev.physical_keycode)}
	if ev is InputEventJoypadButton:
		return {"kind": "jbtn", "btn": int(ev.button_index)}
	if ev is InputEventJoypadMotion:
		return {"kind": "jaxis", "axis": int(ev.axis), "sign": signf(ev.axis_value)}
	return {}

func _deserialize_event(data: Variant) -> InputEvent:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	match str(data.get("kind", "")):
		"key":
			return _key_ev(int(data.get("code", 0)) as Key)
		"jbtn":
			return _joy_btn_ev(int(data.get("btn", 0)) as JoyButton)
		"jaxis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(data.get("axis", 0)) as JoyAxis
			m.axis_value = float(data.get("sign", 1.0))
			return m
	return null

func _event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode)
	if ev is InputEventJoypadButton:
		return "Pad button %d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "Pad axis %d %s" % [ev.axis, "+" if ev.axis_value > 0.0 else "−"]
	return "?"

func _key_ev(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev

func _joy_btn_ev(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev

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
