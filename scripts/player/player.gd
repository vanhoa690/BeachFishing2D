class_name PlayerCharacter
extends CharacterBody2D
## Top-down 2D Player Controller for "Tide & Hook"
## Handles smooth acceleration/friction, animated sprite directional walk cycles, and tool actions.

@export var move_speed: float = 150.0
@export var acceleration: float = 950.0
@export var friction: float = 1200.0
@export var sprite_scale: Vector2 = Vector2(0.08, 0.08)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var dig_particles: CPUParticles2D = $DigParticles

var facing_direction: Vector2 = Vector2.DOWN
var is_locked_action: bool = false
var targeted_interactable: Node = null


func _ready() -> void:
	# Connect to global events
	GameEvents.tool_changed.connect(_on_tool_changed)
	if animated_sprite:
		animated_sprite.scale = sprite_scale
		animated_sprite.play(&"idle_down")


func _unhandled_input(event: InputEvent) -> void:
	# Tool Hotkeys (1: Bare Hands, 2: Shovel, 3: Rod)
	if event.is_action_pressed("tool_slot_1") or (event is InputEventKey and event.pressed and event.keycode == KEY_1):
		GameState.set_tool(GameState.ToolType.NONE)
	elif event.is_action_pressed("tool_slot_2") or (event is InputEventKey and event.pressed and event.keycode == KEY_2):
		GameState.set_tool(GameState.ToolType.SHOVEL)
	elif event.is_action_pressed("tool_slot_3") or (event is InputEventKey and event.pressed and event.keycode == KEY_3):
		GameState.set_tool(GameState.ToolType.FISHING_ROD)
	
	# Tool Cycling (Q / Mouse Wheel)
	elif event.is_action_pressed("tool_cycle_prev"):
		GameState.cycle_tool(-1)
	elif event.is_action_pressed("tool_cycle_next"):
		GameState.cycle_tool(1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameState.cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameState.cycle_tool(1)

	# Interact / Action Trigger
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_E)):
		_handle_interaction()


func _physics_process(delta: float) -> void:
	if is_locked_action:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_animation(true)
		return

	var input_vector := _get_input_vector()

	if input_vector != Vector2.ZERO:
		facing_direction = input_vector
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
		_update_animation(false)
		_update_interaction_ray()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
			_update_animation(true)
		else:
			_update_animation(false)

	move_and_slide()
	_check_interaction_target()


func _update_animation(is_stopped: bool) -> void:
	if not is_instance_valid(animated_sprite):
		return

	if is_stopped:
		var anim_name: StringName = _get_idle_animation()
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		var anim_name: StringName = _get_walk_animation()
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)


func _get_walk_animation() -> StringName:
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			return &"walk_right"
		else:
			return &"walk_left"
	else:
		if velocity.y > 0:
			return &"walk_down"
		else:
			return &"walk_up"


func _get_idle_animation() -> StringName:
	if abs(facing_direction.x) > abs(facing_direction.y):
		if facing_direction.x > 0:
			return &"idle_right"
		else:
			return &"idle_left"
	else:
		if facing_direction.y > 0:
			return &"idle_down"
		else:
			return &"idle_up"


func _get_input_vector() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized()


func _update_interaction_ray() -> void:
	if interaction_ray:
		interaction_ray.target_position = facing_direction * 36.0


func _check_interaction_target() -> void:
	if not interaction_ray:
		return

	var collider = interaction_ray.get_collider()
	var new_target: Node = null

	if collider and collider.has_method("get_interaction_type"):
		new_target = collider
	elif collider and collider.get_parent() and collider.get_parent().has_method("get_interaction_type"):
		new_target = collider.get_parent()

	if new_target != targeted_interactable:
		targeted_interactable = new_target
		if targeted_interactable:
			var prompt_text: String = targeted_interactable.get_interaction_prompt()
			GameEvents.interaction_prompt_requested.emit(prompt_text, targeted_interactable.global_position, true)
		else:
			# Check if facing an is_diggable mud patch tile
			var check_pos := global_position + facing_direction * 22.0
			var current_world := get_tree().current_scene
			if current_world and current_world.has_method("is_pos_diggable") and current_world.is_pos_diggable(check_pos):
				if GameState.current_tool == GameState.ToolType.SHOVEL:
					GameEvents.interaction_prompt_requested.emit("Press [Space] to Dig Mud Patch", check_pos, true)
				else:
					GameEvents.interaction_prompt_requested.emit("Shovel needed! Press [2] to equip", check_pos, true)
			else:
				GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)


func _handle_interaction() -> void:
	if is_locked_action:
		return

	# If facing an interactable target (e.g., DigSpot)
	if targeted_interactable and is_instance_valid(targeted_interactable):
		if targeted_interactable.has_method("interact"):
			targeted_interactable.interact(self)
			return

	# If shovel is equipped and player uses action in open ground
	if GameState.current_tool == GameState.ToolType.SHOVEL:
		var dig_target := global_position + facing_direction * 20.0
		var current_world := get_tree().current_scene
		var is_mud_patch: bool = false
		if current_world and current_world.has_method("is_pos_diggable"):
			is_mud_patch = current_world.is_pos_diggable(dig_target)

		if is_mud_patch:
			perform_mud_dig(dig_target)
		else:
			perform_dig(dig_target)


func perform_mud_dig(dig_pos: Vector2) -> void:
	perform_dig(dig_pos)
	
	# Spawn animated wriggling bait pop effect from the mud patch
	var pop_scene: PackedScene = load("res://scenes/mechanics/bait_pop_effect.tscn")
	if pop_scene:
		var pop_inst = pop_scene.instantiate()
		pop_inst.global_position = dig_pos
		get_parent().add_child(pop_inst)
		pop_inst.launch(randi_range(1, 2), self)


func perform_dig(dig_pos: Vector2) -> void:
	if is_locked_action:
		return

	is_locked_action = true
	_update_animation(true)
	
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "scale", Vector2(sprite_scale.x * 1.15, sprite_scale.y * 0.85), 0.15)
		tween.tween_property(animated_sprite, "scale", sprite_scale, 0.25)
	
	if dig_particles:
		dig_particles.position = facing_direction * 22.0
		dig_particles.restart()
		dig_particles.emitting = true

	GameEvents.player_dig_started.emit(dig_pos)

	var timer: SceneTreeTimer = get_tree().create_timer(0.42)
	timer.timeout.connect(func():
		is_locked_action = false
		GameEvents.player_dig_finished.emit()
	)


func _on_tool_changed(_new_tool: int) -> void:
	pass
