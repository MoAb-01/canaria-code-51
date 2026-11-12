extends Node
## Centralized Runtime Game Session & Story Flag State.
## Manages live quest variables, current environment status, and global input mapping.

var story_flags: Dictionary = {}
var world_state: Dictionary = {}
var current_level: String = ""
var player_spawn_point: Vector2 = Vector2.ZERO
var has_flashlight: bool = true
var is_cutscene_active: bool = false

func _ready() -> void:
	_ensure_global_input_actions()
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("cutscene_state_changed"):
		eb.cutscene_state_changed.connect(func(active: bool): is_cutscene_active = active)

func set_flag(key: String, value: Variant) -> void:
	story_flags[key] = value

func get_flag(key: String, default_value: Variant = false) -> Variant:
	return story_flags.get(key, default_value)

func has_flag(key: String) -> bool:
	return story_flags.has(key)

func clear_flags() -> void:
	story_flags.clear()

func set_world_state(key: String, value: Variant) -> void:
	world_state[key] = value

func get_world_state(key: String, default_value: Variant = null) -> Variant:
	return world_state.get(key, default_value)

func has_world_state(key: String) -> bool:
	return world_state.has(key)

func to_dict() -> Dictionary:
	return {
		"story_flags": story_flags.duplicate(true),
		"world_state": world_state.duplicate(true),
		"current_level": current_level,
		"player_spawn_point": {"x": player_spawn_point.x, "y": player_spawn_point.y},
		"has_flashlight": has_flashlight,
		"is_cutscene_active": is_cutscene_active
	}

func from_dict(data: Dictionary) -> void:
	if not data is Dictionary:
		return
	story_flags = data.get("story_flags", {}).duplicate(true)
	world_state = data.get("world_state", {}).duplicate(true)
	current_level = str(data.get("current_level", ""))
	var sp = data.get("player_spawn_point", {})
	if sp is Dictionary:
		player_spawn_point = Vector2(float(sp.get("x", 0.0)), float(sp.get("y", 0.0)))
	elif sp is Vector2:
		player_spawn_point = sp
	has_flashlight = bool(data.get("has_flashlight", true))
	is_cutscene_active = bool(data.get("is_cutscene_active", false))

func _ensure_global_input_actions() -> void:
	var key_bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C],
		"stealth_crouch": [KEY_CTRL, KEY_C],
		"sprint": [KEY_SHIFT],
		"speed_sprint": [KEY_SHIFT],
		"interact": [KEY_E, KEY_ENTER],
		"toggle_flashlight": [KEY_F],
		"attack": [KEY_J],
		"defend": [KEY_K],
		"ui_cancel": [KEY_ESCAPE],
		"pause": [KEY_ESCAPE, KEY_P],
	}

	for action in key_bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in key_bindings[action]:
			var already_bound := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and ev.physical_keycode == key:
					already_bound = true
					break
			if not already_bound:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

	var mouse_bindings := {
		"attack": MOUSE_BUTTON_LEFT,
		"defend": MOUSE_BUTTON_RIGHT,
	}
	for action in mouse_bindings:
		var btn: int = mouse_bindings[action]
		var has_btn := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton and ev.button_index == btn:
				has_btn = true
				break
		if not has_btn:
			var mb := InputEventMouseButton.new()
			mb.button_index = btn
			InputMap.action_add_event(action, mb)

	var has_dpad := false
	for ev in InputMap.action_get_events("toggle_flashlight"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_DPAD_LEFT:
			has_dpad = true
			break
	if not has_dpad:
		var joy_ev := InputEventJoypadButton.new()
		joy_ev.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("toggle_flashlight", joy_ev)

	for p_action in ["ui_cancel", "pause"]:
		var has_start := false
		for ev in InputMap.action_get_events(p_action):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_START:
				has_start = true
				break
		if not has_start:
			var start_ev := InputEventJoypadButton.new()
			start_ev.button_index = JOY_BUTTON_START
			InputMap.action_add_event(p_action, start_ev)

