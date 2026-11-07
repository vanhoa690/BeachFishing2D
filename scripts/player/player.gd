class_name PlayerCharacter
extends CharacterBody2D
## Top-down 2D Player Controller for "Tide & Hook"
## Handles smooth movement, tool actions, and full fishing loop (casting, bite reaction, reeling minigame).

@export var move_speed: float = 150.0
@export var acceleration: float = 950.0
@export var friction: float = 1200.0
@export var sprite_scale: Vector2 = Vector2(0.08, 0.08)

const BOBBER_SCENE: PackedScene = preload("res://scenes/mechanics/fishing_bobber.tscn")
const REEL_MINIGAME_SCENE: PackedScene = preload("res://scenes/ui/reel_minigame.tscn")
const BAIT_POP_SCENE: PackedScene = preload("res://scenes/mechanics/bait_pop_effect.tscn")

enum FishingState {
	IDLE,
	CHARGING_CAST,
	FISHING_WAITING,
	BITE_WINDOW,
	REELING
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var dig_particles: CPUParticles2D = $DigParticles
@onready var rod_visual: RodVisual = $RodVisual
@onready var cast_indicator: CastIndicator = $CastIndicator

var facing_direction: Vector2 = Vector2.LEFT
var is_locked_action: bool = false
var targeted_interactable: Node = null

# Fishing system state
var fishing_state: FishingState = FishingState.IDLE
var current_bobber: FishingBobber = null
var current_minigame: ReelMinigame = null
var cast_charge_timer: float = 0.0
var cast_charge_ratio: float = 0.0
var target_cast_pos: Vector2 = Vector2.ZERO
var rack_ghost: Sprite2D = null


func _ready() -> void:
	GameEvents.tool_changed.connect(_on_tool_changed)
	if animated_sprite:
		animated_sprite.scale = sprite_scale
		animated_sprite.play(&"idle_left")
	_update_rod_visual()
	_init_rack_ghost()


func _unhandled_input(event: InputEvent) -> void:
	# Ignore tool swapping while in an active minigame or locked action
	if fishing_state == FishingState.REELING:
		return

	# Tool Hotkeys (1: Bare Hands, 2: Shovel, 3: Rod)
	if event.is_action_pressed("tool_slot_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1):
		_cancel_active_fishing()
		GameState.set_tool(GameState.ToolType.NONE)
	elif event.is_action_pressed("tool_slot_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2):
		_cancel_active_fishing()
		GameState.set_tool(GameState.ToolType.SHOVEL)
	elif event.is_action_pressed("tool_slot_3") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_3):
		_cancel_active_fishing()
		GameState.set_tool(GameState.ToolType.FISHING_ROD)
	elif event.is_action_pressed("tool_slot_4") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_4):
		_cancel_active_fishing()
		GameState.set_tool(GameState.ToolType.DRYING_RACK)
	
	# Tool Cycling (Q / Tab / Mouse Wheel)
	elif event.is_action_pressed("tool_cycle_prev"):
		_cancel_active_fishing()
		GameState.cycle_tool(-1)
	elif event.is_action_pressed("tool_cycle_next"):
		_cancel_active_fishing()
		GameState.cycle_tool(1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cancel_active_fishing()
			GameState.cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cancel_active_fishing()
			GameState.cycle_tool(1)

	# Fishing & Interaction Handling
	_handle_action_inputs(event)


func _handle_action_inputs(event: InputEvent) -> void:
	var is_action_press: bool = false
	var is_action_release: bool = false

	if event.is_action_pressed("interact"):
		is_action_press = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_E):
		is_action_press = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_action_press = true

	if event.is_action_released("interact"):
		is_action_release = true
	elif event is InputEventKey and not event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_E):
		is_action_release = true
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_action_release = true

	# 1. Fishing Rod Specific Inputs
	if GameState.current_tool == GameState.ToolType.FISHING_ROD:
		match fishing_state:
			FishingState.IDLE:
				if is_action_press:
					if _is_facing_water():
						if GameState.has_bait():
							_start_cast_charging()
							get_viewport().set_input_as_handled()
						else:
							GameEvents.emit_notification("No bait! Dig for sand worms on mud patches first.")
							get_viewport().set_input_as_handled()
					else:
						# General interaction if targeting something
						_handle_general_interaction()

			FishingState.CHARGING_CAST:
				if is_action_release:
					_release_and_cast()
					get_viewport().set_input_as_handled()

			FishingState.FISHING_WAITING:
				if is_action_press:
					# Cancel cast and reel line back peacefully
					_cancel_active_fishing()
					get_viewport().set_input_as_handled()

			FishingState.BITE_WINDOW:
				if is_action_press:
					# Player reacted in time! Hook the fish!
					_attempt_hook()
					get_viewport().set_input_as_handled()

			FishingState.REELING:
				pass

	# 2. Drying Rack Placement
	elif GameState.current_tool == GameState.ToolType.DRYING_RACK:
		if is_action_press:
			_attempt_place_drying_rack()
			get_viewport().set_input_as_handled()

	# 3. General Non-Fishing Inputs (Hands, Shovel)
	else:
		if is_action_press:
			_handle_general_interaction()


func _physics_process(delta: float) -> void:
	# Process Cast Charging
	if fishing_state == FishingState.CHARGING_CAST:
		_process_cast_charging(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(true)
		return

	if is_locked_action or fishing_state != FishingState.IDLE:
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
		_update_rod_visual()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
			_update_animation(true)
		else:
			_update_animation(false)

	move_and_slide()
	_check_interaction_target()


func _process_cast_charging(delta: float) -> void:
	cast_charge_timer += delta * 2.2
	# Smooth oscillating power curve between 0.0 and 1.0
	cast_charge_ratio = (sin(cast_charge_timer - PI * 0.5) + 1.0) * 0.5
	var cast_distance: float = lerp(60.0, 180.0, cast_charge_ratio)

	var lateral_skew: float = 0.0
	if abs(facing_direction.x) < 0.2:
		lateral_skew = -1.0 # Force westward cast if facing north/south near shore
	else:
		lateral_skew = signf(facing_direction.x)

	var raw_target := global_position + Vector2(lateral_skew * cast_distance, facing_direction.y * cast_distance * 0.4)
	# Clamp landing inside water bounds (ocean is x <= 480)
	raw_target.x = clampf(raw_target.x, 32.0, 480.0)
	raw_target.y = clampf(raw_target.y, 48.0, 976.0)
	target_cast_pos = raw_target

	var rod_tip: Vector2 = global_position + Vector2(facing_direction.x * 12.0, -12.0)
	if cast_indicator:
		cast_indicator.update_aim(rod_tip, target_cast_pos, cast_charge_ratio)

	if rod_visual:
		rod_visual.update_rod(true, facing_direction, -cast_charge_ratio * 0.8)


func _start_cast_charging() -> void:
	fishing_state = FishingState.CHARGING_CAST
	is_locked_action = true
	cast_charge_timer = 0.0
	cast_charge_ratio = 0.0
	if cast_indicator:
		cast_indicator.start_aiming()


func _release_and_cast() -> void:
	if not BOBBER_SCENE:
		return

	fishing_state = FishingState.FISHING_WAITING
	is_locked_action = true
	if cast_indicator:
		cast_indicator.stop_aiming()

	if rod_visual:
		rod_visual.update_rod(true, facing_direction, 0.5) # Cast follow-through flex

	var bobber_inst: FishingBobber = BOBBER_SCENE.instantiate() as FishingBobber
	current_bobber = bobber_inst

	# Spawn bobber in current world
	var spawn_parent: Node = get_parent()
	if not spawn_parent:
		spawn_parent = self
	spawn_parent.add_child(bobber_inst)

	var launch_origin: Vector2 = global_position + Vector2(facing_direction.x * 12.0, -12.0)
	bobber_inst.launch(launch_origin, target_cast_pos, self)

	# Connect bobber signals
	bobber_inst.landed.connect(_on_bobber_landed)
	bobber_inst.fish_biting.connect(_on_bobber_biting)
	bobber_inst.hook_missed.connect(_on_bobber_hook_missed)
	bobber_inst.hook_success.connect(_on_bobber_hook_success)
	bobber_inst.reeled_in.connect(_on_bobber_reeled_in)

	GameEvents.fishing_cast_started.emit(target_cast_pos)
	GameEvents.interaction_prompt_requested.emit("Line cast! Waiting for a bite...", target_cast_pos, true)


func _on_bobber_landed(_pos: Vector2) -> void:
	if rod_visual:
		rod_visual.update_rod(true, facing_direction, 0.0)
	GameEvents.interaction_prompt_requested.emit("Waiting for a bite... [Space to Cancel]", _pos, true)


func _on_bobber_biting() -> void:
	fishing_state = FishingState.BITE_WINDOW
	if rod_visual:
		rod_visual.update_rod(true, facing_direction, 1.2) # Rod jerking down!
	GameEvents.interaction_prompt_requested.emit("FISH ON! Press [Space] / [L-Click] NOW!", global_position + Vector2(0, -32), true)


func _attempt_hook() -> void:
	if current_bobber and is_instance_valid(current_bobber):
		current_bobber.try_hook()


func _on_bobber_hook_success() -> void:
	fishing_state = FishingState.REELING
	GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)
	_start_reeling_minigame()


func _on_bobber_hook_missed() -> void:
	# Bait lost on missed reaction window
	GameState.consume_bait()
	GameEvents.emit_notification("Too slow! The fish stole your bait and escaped.")
	_finish_fishing_session(false)


func _start_reeling_minigame() -> void:
	if not REEL_MINIGAME_SCENE:
		return

	var minigame: ReelMinigame = REEL_MINIGAME_SCENE.instantiate() as ReelMinigame
	current_minigame = minigame
	get_tree().root.add_child(minigame)
	minigame.minigame_finished.connect(_on_minigame_finished)
	minigame.start_game()
	GameEvents.fishing_reeling_started.emit()


func _on_minigame_finished(success: bool) -> void:
	if success:
		# Consume 1 bait upon successful catch
		GameState.consume_bait()

		# Roll fish by rarity weight
		var caught_fish: FishData = GameState.roll_random_fish()
		if caught_fish:
			var catch_weight: float = caught_fish.roll_weight()
			GameEvents.fish_caught.emit(caught_fish, catch_weight)
		else:
			GameEvents.emit_notification("Fish caught!")

		_finish_fishing_session(true)
	else:
		# Consume 1 bait on line snap / escape
		GameState.consume_bait()
		GameEvents.emit_notification("The fish broke free and took your bait!")
		_finish_fishing_session(false)


func _finish_fishing_session(success: bool) -> void:
	if is_instance_valid(current_bobber):
		current_bobber.reel_in()
	current_bobber = null
	current_minigame = null
	fishing_state = FishingState.IDLE
	is_locked_action = false
	_update_rod_visual()
	GameEvents.fishing_ended.emit(success)
	GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)


func _cancel_active_fishing() -> void:
	if cast_indicator:
		cast_indicator.stop_aiming()
	if is_instance_valid(current_minigame):
		current_minigame.queue_free()
		current_minigame = null
	if is_instance_valid(current_bobber):
		current_bobber.cancel_cast()
		current_bobber = null

	fishing_state = FishingState.IDLE
	is_locked_action = false
	_update_rod_visual()
	GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)


func _on_bobber_reeled_in() -> void:
	current_bobber = null
	fishing_state = FishingState.IDLE
	is_locked_action = false
	_update_rod_visual()


func _update_rod_visual() -> void:
	if rod_visual:
		var has_rod: bool = (GameState.current_tool == GameState.ToolType.FISHING_ROD)
		rod_visual.update_rod(has_rod, facing_direction, 0.0)


func _is_facing_water() -> bool:
	var current_world := get_tree().current_scene
	var cast_check_pos := global_position + facing_direction * 70.0
	if current_world and current_world.has_method("is_pos_water"):
		if current_world.is_pos_water(cast_check_pos):
			return true

	# Shoreline is at x <= 520; if player is within coastal zone and facing west
	if facing_direction.x < -0.2 and global_position.x <= 750.0:
		return true

	return false


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
		return &"walk_right" if velocity.x > 0 else &"walk_left"
	else:
		return &"walk_down" if velocity.y > 0 else &"walk_up"


func _get_idle_animation() -> StringName:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return &"idle_right" if facing_direction.x > 0 else &"idle_left"
	else:
		return &"idle_down" if facing_direction.y > 0 else &"idle_up"


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
	# While fishing, prompt is managed by fishing states
	if fishing_state != FishingState.IDLE:
		return

	# If holding Fishing Rod near water
	if GameState.current_tool == GameState.ToolType.FISHING_ROD:
		if _is_facing_water():
			var hint_pos := global_position + Vector2(-36.0, -18.0)
			if GameState.has_bait():
				GameEvents.interaction_prompt_requested.emit("Press [Space] / [Left Click] to Cast", hint_pos, true)
			else:
				GameEvents.interaction_prompt_requested.emit("No Bait! Dig mud with Shovel [2]", hint_pos, true)
			return

	# If holding Drying Rack Kit
	if GameState.current_tool == GameState.ToolType.DRYING_RACK:
		var place_pos := global_position + facing_direction * 36.0
		var current_world := get_tree().current_scene
		var is_valid_sand: bool = true
		if current_world:
			if current_world.has_method("is_pos_water") and current_world.is_pos_water(place_pos):
				is_valid_sand = false
			elif current_world.has_method("is_pos_diggable") and current_world.is_pos_diggable(place_pos):
				is_valid_sand = false
		if place_pos.x < 530.0:
			is_valid_sand = false

		if is_valid_sand:
			GameEvents.interaction_prompt_requested.emit("Press [Space] / [Left Click] to Place Rack", place_pos, true)
		else:
			GameEvents.interaction_prompt_requested.emit("Cannot place here (Needs open dry sand)", place_pos, true)

		_update_rack_ghost(true, place_pos, is_valid_sand)
		return
	else:
		_update_rack_ghost(false, Vector2.ZERO, false)

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
			# Check if facing an is_diggable mud patch tile (ONLY if shovel or bare hands)
			if GameState.current_tool == GameState.ToolType.SHOVEL or GameState.current_tool == GameState.ToolType.NONE:
				var check_pos := global_position + facing_direction * 22.0
				var current_world := get_tree().current_scene
				if current_world and current_world.has_method("is_pos_diggable") and current_world.is_pos_diggable(check_pos):
					if GameState.current_tool == GameState.ToolType.SHOVEL:
						GameEvents.interaction_prompt_requested.emit("Press [Space] to Dig Mud Patch", check_pos, true)
					else:
						GameEvents.interaction_prompt_requested.emit("Shovel needed! Press [2] to equip", check_pos, true)
				else:
					GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)
			else:
				GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)


func _handle_general_interaction() -> void:
	if is_locked_action:
		return

	# If facing an interactable target (e.g. DigSpot)
	if targeted_interactable and is_instance_valid(targeted_interactable):
		if targeted_interactable.has_method("interact"):
			targeted_interactable.interact(self)
			return

	# If shovel is equipped and player uses action in ground
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
	
	if BAIT_POP_SCENE:
		var pop_inst = BAIT_POP_SCENE.instantiate()
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


func _on_tool_changed(new_tool: int) -> void:
	_update_rod_visual()
	if new_tool != GameState.ToolType.DRYING_RACK:
		_update_rack_ghost(false, Vector2.ZERO, false)


func _init_rack_ghost() -> void:
	rack_ghost = Sprite2D.new()
	var tex = load("res://sprites/props/fish-drying-rack.png")
	if tex:
		rack_ghost.texture = tex
	rack_ghost.scale = Vector2(0.038, 0.038)
	rack_ghost.visible = false
	rack_ghost.top_level = true
	add_child(rack_ghost)


func _update_rack_ghost(show: bool, target_pos: Vector2, is_valid: bool) -> void:
	if not is_instance_valid(rack_ghost):
		return
	rack_ghost.visible = show
	if show:
		rack_ghost.global_position = target_pos + Vector2(0, -18.0)
		if is_valid:
			rack_ghost.modulate = Color(0.4, 1.0, 0.5, 0.65)
		else:
			rack_ghost.modulate = Color(1.0, 0.35, 0.35, 0.6)


func _attempt_place_drying_rack() -> void:
	if targeted_interactable and is_instance_valid(targeted_interactable):
		if targeted_interactable.has_method("interact"):
			targeted_interactable.interact(self)
			return

	var place_pos := global_position + facing_direction * 36.0
	var current_world := get_tree().current_scene
	if not current_world:
		return

	if (current_world.has_method("is_pos_water") and current_world.is_pos_water(place_pos)) or place_pos.x < 530.0:
		GameEvents.emit_notification("Cannot place rack in the water! Choose dry beach sand.")
		return

	if current_world.has_method("is_pos_diggable") and current_world.is_pos_diggable(place_pos):
		GameEvents.emit_notification("Cannot place rack over a worm mud patch! Choose clean sand.")
		return

	var rack_scene: PackedScene = load("res://scenes/mechanics/fish_drying_rack.tscn")
	if rack_scene:
		var rack_inst: FishDryingRack = rack_scene.instantiate() as FishDryingRack
		rack_inst.global_position = place_pos
		get_parent().add_child(rack_inst)
		GameEvents.emit_notification("Constructed a Fish Drying Rack on the shore!")

		if dig_particles:
			dig_particles.position = facing_direction * 22.0
			dig_particles.restart()
			dig_particles.emitting = true
