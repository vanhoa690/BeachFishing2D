extends Node
## Central Event Bus for "Tide & Hook"
## Decouples gameplay systems, mechanics, and UI via typed signals.

signal tool_changed(new_tool: int)
signal worm_dug(amount: int, world_position: Vector2)
signal worms_count_changed(total_worms: int)
signal interaction_prompt_requested(text: String, world_pos: Vector2, show: bool)
signal player_dig_started(target_position: Vector2)
signal player_dig_finished()
signal notification_banner(message: String)


func _enter_tree() -> void:
	_ensure_input_mappings()


func _ensure_input_mappings() -> void:
	_register_action_keys("move_left", [KEY_A, KEY_LEFT])
	_register_action_keys("move_right", [KEY_D, KEY_RIGHT])
	_register_action_keys("move_up", [KEY_W, KEY_UP])
	_register_action_keys("move_down", [KEY_S, KEY_DOWN])
	_register_action_keys("interact", [KEY_SPACE, KEY_E])
	_register_action_keys("tool_cycle_prev", [KEY_Q])
	_register_action_keys("tool_cycle_next", [KEY_TAB])
	_register_action_keys("tool_slot_1", [KEY_1])
	_register_action_keys("tool_slot_2", [KEY_2])
	_register_action_keys("tool_slot_3", [KEY_3])


func _register_action_keys(action_name: StringName, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var has_key: bool = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.physical_keycode == key:
				has_key = true
				break
		if not has_key:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action_name, event)

