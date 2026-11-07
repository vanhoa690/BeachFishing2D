class_name DigSpot
extends Area2D
## Interactive Sandy Worm Mound for "Tide & Hook"
## Coastal digging spot yielding sand worms when excavated with a shovel.

enum SpotState {
	ACTIVE,
	EXHAUSTED
}

@export var min_worms_yield: int = 1
@export var max_worms_yield: int = 2
@export var respawn_time: float = 12.0

@onready var sand_particles: CPUParticles2D = $SandParticles
@onready var bubble_timer: Timer = $BubbleTimer
@onready var respawn_timer: Timer = $RespawnTimer

var current_state: SpotState = SpotState.ACTIVE


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	
	respawn_timer.wait_time = respawn_time
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timeout)
	
	if bubble_timer:
		bubble_timer.wait_time = randf_range(2.0, 3.5)
		bubble_timer.timeout.connect(_on_bubble_timeout)
	
	queue_redraw()


func _on_bubble_timeout() -> void:
	if current_state == SpotState.ACTIVE:
		_emit_sand_bubble()
		if bubble_timer:
			bubble_timer.start(randf_range(2.0, 4.0))


func get_interaction_type() -> String:
	return "dig_spot"


func get_interaction_prompt() -> String:
	if current_state == SpotState.EXHAUSTED:
		return "Exhausted burrow (wait for tide)"
	
	if GameState.current_tool == GameState.ToolType.SHOVEL:
		return "Press [Space] to Dig for Sand Worms"
	else:
		return "Shovel needed! Press [2] to equip"


func interact(player: Node2D) -> void:
	if current_state == SpotState.EXHAUSTED:
		GameEvents.notification_banner.emit("The sand here has already been turned over.")
		return

	if GameState.current_tool != GameState.ToolType.SHOVEL:
		GameEvents.notification_banner.emit("You need a Sand Shovel to dig here! Press [2].")
		return

	# Trigger player animation
	if player.has_method("perform_dig"):
		player.perform_dig(global_position)

	# Execute dig logic
	current_state = SpotState.EXHAUSTED
	queue_redraw()

	if sand_particles:
		sand_particles.restart()
		sand_particles.emitting = true

	# Calculate worm drop
	var yield_amount: int = randi_range(min_worms_yield, max_worms_yield)
	GameState.add_worms(yield_amount)
	GameEvents.worm_dug.emit(yield_amount, global_position)

	# Begin respawn cooldown
	respawn_timer.start(respawn_time)
	
	# Update prompt
	GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_respawn_timeout() -> void:
	current_state = SpotState.ACTIVE
	queue_redraw()
	_emit_sand_bubble()


func _emit_sand_bubble() -> void:
	if sand_particles and current_state == SpotState.ACTIVE:
		sand_particles.amount = 4
		sand_particles.restart()
		sand_particles.emitting = true


func _draw() -> void:
	if current_state == SpotState.ACTIVE:
		# Undug Sand Mound
		# Shadow
		draw_circle(Vector2(0, 3), 11.0, Color(0.72, 0.62, 0.44, 0.6))
		# Main sand mound
		draw_circle(Vector2(0, 0), 10.0, Color(0.92, 0.82, 0.58))
		# Mound highlight
		draw_circle(Vector2(-2, -2), 6.5, Color(0.96, 0.88, 0.68))
		# Worm burrow hole
		draw_circle(Vector2(1, 0), 3.0, Color(0.38, 0.28, 0.18))
		draw_circle(Vector2(1.5, 0.5), 1.8, Color(0.20, 0.14, 0.08))
		# Subtle sand specks
		draw_circle(Vector2(-5, 4), 1.0, Color(0.68, 0.56, 0.38))
		draw_circle(Vector2(6, -3), 1.2, Color(0.78, 0.66, 0.46))
	else:
		# Dug Sand Crater / Pit
		# Outer dug crater
		draw_circle(Vector2(0, 2), 12.0, Color(0.65, 0.54, 0.36, 0.7))
		# Excavated sand pit
		draw_circle(Vector2(0, 0), 9.0, Color(0.48, 0.36, 0.22))
		# Deep center
		draw_circle(Vector2(0, 0), 5.5, Color(0.28, 0.20, 0.12))
		# Clods of displaced moist sand
		draw_circle(Vector2(-8, 3), 2.5, Color(0.55, 0.42, 0.28))
		draw_circle(Vector2(7, 4), 2.2, Color(0.58, 0.45, 0.30))
		draw_circle(Vector2(-3, -7), 2.0, Color(0.60, 0.48, 0.32))
		draw_circle(Vector2(5, -6), 2.8, Color(0.55, 0.42, 0.28))

