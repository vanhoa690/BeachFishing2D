class_name FishingBobber
extends Node2D
## Interactive Floating Fishing Bobber for "Tide & Hook"
## Handles cast arc trajectory, surface bobbing, bite timing, hook reaction window, and line drawing.

signal landed(world_pos: Vector2)
signal fish_biting()
signal hook_success()
signal hook_missed()
signal reeled_in()

enum State {
	LAUNCHING,
	FLOATING,
	BITING,
	HOOKED,
	REELING,
	CANCELLED
}

var current_state: State = State.LAUNCHING
var player_ref: Node2D = null

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_progress: float = 0.0
const FLIGHT_DURATION: float = 0.55
const ARC_HEIGHT: float = 45.0

var elapsed_time: float = 0.0
var bite_delay: float = 3.0
var bite_timer: float = 0.0
var has_nibbled: bool = false
var reaction_timer: float = 1.2
const MAX_REACTION_WINDOW: float = 1.2

@onready var visual_node: Node2D = $BobberVisual
@onready var alert_bubble: Node2D = $AlertBubble
@onready var splash_particles: CPUParticles2D = $SplashParticles
@onready var fishing_line: Line2D = $FishingLine


func _ready() -> void:
	if alert_bubble:
		alert_bubble.visible = false
		alert_bubble.scale = Vector2.ZERO

	# Configure fishing line visual
	if fishing_line:
		fishing_line.top_level = true
		fishing_line.width = 1.2
		fishing_line.default_color = Color(0.92, 0.95, 1.0, 0.7)


func launch(origin: Vector2, landing_target: Vector2, caster: Node2D) -> void:
	player_ref = caster
	start_pos = origin
	target_pos = landing_target
	global_position = origin
	current_state = State.LAUNCHING
	flight_progress = 0.0

	# Randomize bite wait time (2.0 to 5.0 seconds as specified)
	bite_delay = randf_range(2.0, 4.8)
	bite_timer = 0.0
	has_nibbled = false
	reaction_timer = MAX_REACTION_WINDOW

	# Launch tween
	var tween := create_tween()
	tween.tween_method(_update_flight_arc, 0.0, 1.0, FLIGHT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_landed)


func _update_flight_arc(progress: float) -> void:
	flight_progress = progress
	var horizontal_pos: Vector2 = start_pos.lerp(target_pos, progress)
	# Parabolic height curve: 4 * h * p * (1 - p)
	var height_offset: float = -4.0 * ARC_HEIGHT * progress * (1.0 - progress)
	global_position = horizontal_pos + Vector2(0, height_offset)
	_update_line()


func _on_landed() -> void:
	current_state = State.FLOATING
	global_position = target_pos
	_update_line()
	
	if splash_particles:
		splash_particles.restart()
		splash_particles.emitting = true

	landed.emit(target_pos)
	GameEvents.fishing_bobber_landed.emit(target_pos)


func _process(delta: float) -> void:
	elapsed_time += delta
	_update_line()

	match current_state:
		State.FLOATING:
			_process_floating(delta)
		State.BITING:
			_process_biting(delta)
		State.HOOKED:
			# Fast struggle vibration while minigame runs
			if visual_node:
				visual_node.position.y = 3.0 + sin(elapsed_time * 20.0) * 2.0
				visual_node.position.x = cos(elapsed_time * 25.0) * 1.5


func _process_floating(delta: float) -> void:
	# Gentle water surface bobbing
	if visual_node:
		visual_node.position.y = sin(elapsed_time * 3.2) * 2.5
		visual_node.position.x = 0.0

	bite_timer += delta

	# Subtle pre-bite nibble twitch at ~70% time
	if not has_nibbled and bite_timer >= (bite_delay * 0.72):
		has_nibbled = true
		_play_nibble_twitch()

	# Fish bites!
	if bite_timer >= bite_delay:
		_trigger_fish_bite()


func _play_nibble_twitch() -> void:
	if visual_node:
		var twitch_tween := create_tween()
		twitch_tween.tween_property(visual_node, "position:y", 4.0, 0.08)
		twitch_tween.tween_property(visual_node, "position:y", 0.0, 0.12)
	if splash_particles:
		splash_particles.restart()
		splash_particles.emitting = true


func _trigger_fish_bite() -> void:
	current_state = State.BITING
	reaction_timer = MAX_REACTION_WINDOW

	# Splash particles on bite
	if splash_particles:
		splash_particles.restart()
		splash_particles.emitting = true

	# Alert exclamation bubble pops up
	if alert_bubble:
		alert_bubble.visible = true
		alert_bubble.scale = Vector2.ZERO
		var pop_tween := create_tween()
		pop_tween.tween_property(alert_bubble, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(alert_bubble, "scale", Vector2(1.0, 1.0), 0.1)

	fish_biting.emit()
	GameEvents.fishing_bite_alert.emit(global_position)


func _process_biting(delta: float) -> void:
	# Urgent bobber submerging and shaking
	if visual_node:
		visual_node.position.y = 4.5 + sin(elapsed_time * 22.0) * 2.5
		visual_node.position.x = sin(elapsed_time * 30.0) * 2.0

	reaction_timer -= delta
	if reaction_timer <= 0.0:
		_on_bite_timeout()


func _on_bite_timeout() -> void:
	current_state = State.CANCELLED
	if alert_bubble:
		var fade_tween := create_tween()
		fade_tween.tween_property(alert_bubble, "scale", Vector2.ZERO, 0.15)
	
	hook_missed.emit()
	reel_in()


func try_hook() -> bool:
	if current_state != State.BITING:
		return false

	current_state = State.HOOKED
	
	# Pop exclamation bubble away
	if alert_bubble:
		var hook_tween := create_tween()
		hook_tween.tween_property(alert_bubble, "scale", Vector2(1.4, 1.4), 0.08)
		hook_tween.tween_property(alert_bubble, "scale", Vector2.ZERO, 0.12)
		hook_tween.finished.connect(func(): if alert_bubble: alert_bubble.visible = false)

	if splash_particles:
		splash_particles.restart()
		splash_particles.emitting = true

	hook_success.emit()
	return true


func reel_in(on_finished: Callable = Callable()) -> void:
	current_state = State.REELING
	var return_pos := global_position
	if is_instance_valid(player_ref):
		return_pos = player_ref.global_position + Vector2(0, -10)

	var tween := create_tween()
	tween.tween_property(self, "global_position", return_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		reeled_in.emit()
		if on_finished.is_valid():
			on_finished.call()
		queue_free()
	)


func cancel_cast() -> void:
	reel_in()


func _update_line() -> void:
	if not is_instance_valid(fishing_line):
		return
	if not is_instance_valid(player_ref):
		fishing_line.clear_points()
		return

	# Rod tip position on player
	var rod_tip: Vector2 = player_ref.global_position + Vector2(player_ref.facing_direction.x * 12.0, -14.0)
	var bobber_tip: Vector2 = global_position + (visual_node.position if visual_node else Vector2.ZERO) + Vector2(0, -6)

	fishing_line.clear_points()
	
	# If line is slack during floating, calculate slight sag
	if current_state == State.FLOATING:
		var mid_point: Vector2 = rod_tip.lerp(bobber_tip, 0.5) + Vector2(0, 10.0 + sin(elapsed_time * 2.0) * 2.0)
		fishing_line.add_point(rod_tip)
		fishing_line.add_point(mid_point)
		fishing_line.add_point(bobber_tip)
	else:
		# Taut line when hooked/biting/flying
		fishing_line.add_point(rod_tip)
		fishing_line.add_point(bobber_tip)

