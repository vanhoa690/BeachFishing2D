extends Node
## Central Event Bus for "Tide & Hook"
## Decouples gameplay systems, mechanics, and UI via typed signals.

@warning_ignore("unused_signal")
signal tool_changed(new_tool: int)

@warning_ignore("unused_signal")
signal worm_dug(amount: int, world_position: Vector2)

@warning_ignore("unused_signal")
signal worms_count_changed(total_worms: int)

@warning_ignore("unused_signal")
signal interaction_prompt_requested(text: String, world_pos: Vector2, show: bool)

@warning_ignore("unused_signal")
signal player_dig_started(target_position: Vector2)

@warning_ignore("unused_signal")
signal player_dig_finished()

@warning_ignore("unused_signal")
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


# Public helper emitters
func emit_tool_changed(new_tool: int) -> void:
	tool_changed.emit(new_tool)


func emit_worm_dug(amount: int, world_position: Vector2) -> void:
	worm_dug.emit(amount, world_position)


func emit_worms_count_changed(total_worms: int) -> void:
	worms_count_changed.emit(total_worms)


func emit_interaction_prompt(text: String, world_pos: Vector2, show: bool) -> void:
	interaction_prompt_requested.emit(text, world_pos, show)


func emit_player_dig_started(target_position: Vector2) -> void:
	player_dig_started.emit(target_position)


func emit_player_dig_finished() -> void:
	player_dig_finished.emit()


func emit_notification(message: String) -> void:
	notification_banner.emit(message)
