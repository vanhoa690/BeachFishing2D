class_name PlayerCharacter
extends CharacterBody2D
## Top-down 2D Player Controller for "Tide & Hook"
## Handles smooth acceleration/friction, tool equipment, aiming, and digging actions.

@export var move_speed: float = 150.0
@export var acceleration: float = 950.0
@export var friction: float = 1200.0

@onready var visuals: Node2D = $Visuals
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var dig_particles: CPUParticles2D = $DigParticles

var facing_direction: Vector2 = Vector2.DOWN
var is_locked_action: bool = false
var targeted_interactable: Node = null


func _ready() -> void:
	# Connect to global events
	GameEvents.tool_changed.connect(_on_tool_changed)
	if visuals:
		visuals.set_tool(GameState.current_tool)
		visuals.facing_direction = facing_direction


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
		if visuals:
			visuals.is_moving = false
		return

	var input_vector := _get_input_vector()

	if input_vector != Vector2.ZERO:
		facing_direction = input_vector
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
		if visuals:
			visuals.is_moving = true
			visuals.facing_direction = facing_direction
		_update_interaction_ray()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if visuals:
			visuals.is_moving = false

	move_and_slide()
	_check_interaction_target()


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
			GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)


func _handle_interaction() -> void:
	if is_locked_action:
		return

	# If facing an interactable target (e.g., DigSpot)
	if targeted_interactable and is_instance_valid(targeted_interactable):
		if targeted_interactable.has_method("interact"):
			targeted_interactable.interact(self)
			return

	# If shovel is equipped and player uses action in open sand
	if GameState.current_tool == GameState.ToolType.SHOVEL:
		perform_dig(global_position + facing_direction * 20.0)


func perform_dig(dig_pos: Vector2) -> void:
	if is_locked_action:
		return

	is_locked_action = true
	if visuals:
		visuals.play_dig_animation(0.42)
	
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


func _on_tool_changed(new_tool: int) -> void:
	if visuals:
		visuals.set_tool(new_tool)

