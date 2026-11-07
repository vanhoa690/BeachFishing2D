class_name Seagull
extends Node2D
## Coastal Seagull AI for "Tide & Hook"
## Features 2.5D flight with ground shadow projection, rack surveillance, swooping fish-theft, and player-flee reactions.

enum State {
	PATROL,
	DIVE_STEAL,
	FLEE,
	ESCAPE
}

@export var flight_speed: float = 75.0
@export var dive_speed: float = 165.0
@export var flee_speed: float = 195.0
@export var base_patrol_altitude: float = 110.0

var current_state: State = State.PATROL
var target_rack: FishDryingRack = null
var target_rack_pos: Vector2 = Vector2.ZERO

var ground_pos: Vector2 = Vector2.ZERO
var altitude: float = 110.0
var flight_dir: float = 1.0 # 1.0 = right, -1.0 = left
var time_alive: float = 0.0
var detect_cooldown: float = 1.2
var current_tween: Tween = null
var chirp_player: AudioStreamPlayer2D = null

@onready var flyer_node: Node2D = $FlyerNode
@onready var animated_sprite: AnimatedSprite2D = $FlyerNode/AnimatedSprite2D
@onready var alert_bubble: Node2D = $FlyerNode/AlertMark
@onready var beak_fish: Sprite2D = $FlyerNode/BeakFish
@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var squawk_particles: CPUParticles2D = $FlyerNode/SquawkParticles


func _ready() -> void:
	add_to_group("seagull")
	ground_pos = global_position
	altitude = base_patrol_altitude
	flight_dir = 1.0 if randf() > 0.5 else -1.0

	if animated_sprite:
		animated_sprite.play(&"fly")
	if alert_bubble:
		alert_bubble.visible = false
	if beak_fish:
		beak_fish.visible = false

	_init_chirp_audio()
	_update_transforms()


func _physics_process(delta: float) -> void:
	time_alive += delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.DIVE_STEAL:
			_process_dive_steal(delta)
		State.FLEE:
			pass # Managed via tween
		State.ESCAPE:
			pass # Managed via tween

	_update_transforms()


func _process_patrol(delta: float) -> void:
	# Horizontal sine-wave cruising across the beach sky
	ground_pos.x += flight_speed * flight_dir * delta
	ground_pos.y += sin(time_alive * 1.8) * 22.0 * delta

	# Natural gentle altitude hovering
	altitude = base_patrol_altitude + sin(time_alive * 2.4) * 12.0

	# Turn around at map borders
	if ground_pos.x < 360.0:
		flight_dir = 1.0
	elif ground_pos.x > 1450.0:
		flight_dir = -1.0

	if ground_pos.y < 120.0:
		ground_pos.y = 120.0
	elif ground_pos.y > 880.0:
		ground_pos.y = 880.0

	# Sprite orientation
	if animated_sprite:
		animated_sprite.flip_h = (flight_dir < 0.0)
		if animated_sprite.animation != &"fly":
			animated_sprite.play(&"fly")

	# Periodically detect occupied drying racks
	detect_cooldown -= delta
	if detect_cooldown <= 0.0:
		detect_cooldown = randf_range(1.2, 2.2)
		_scan_for_drying_racks()


func _scan_for_drying_racks() -> void:
	var racks: Array[Node] = get_tree().get_nodes_in_group("drying_rack")
	if racks.is_empty():
		return

	var player := _get_player()
	if not player:
		return

	# Find any drying rack that has a fish and is vulnerable
	for node in racks:
		var rack := node as FishDryingRack
		if not rack or not is_instance_valid(rack):
			continue

		# Check if rack has a fish and is NOT safe storage
		if rack.has_fish and not rack.is_safe_storage:
			var player_dist: float = player.global_position.distance_to(rack.global_position)
			# Only dive if player distance to that rack is > 140 pixels
			if player_dist > 140.0:
				_start_dive(rack)
				break


func _start_dive(rack: FishDryingRack) -> void:
	target_rack = rack
	target_rack_pos = rack.global_position
	current_state = State.DIVE_STEAL

	# Face the target rack
	flight_dir = -1.0 if (target_rack_pos.x < ground_pos.x) else 1.0
	if animated_sprite:
		animated_sprite.play(&"dive")
		animated_sprite.flip_h = (flight_dir < 0.0)

	# Pop exclamation alert "!"
	if alert_bubble:
		alert_bubble.visible = true
		alert_bubble.scale = Vector2.ZERO
		var pop_tween := create_tween()
		pop_tween.tween_property(alert_bubble, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
		pop_tween.tween_property(alert_bubble, "scale", Vector2.ONE, 0.1)

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	# Swoop down via Tween
	var dive_dist: float = ground_pos.distance_to(target_rack_pos)
	var dive_duration: float = clampf(dive_dist / dive_speed, 1.2, 2.4)

	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "ground_pos", target_rack_pos, dive_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	current_tween.tween_property(self, "altitude", 16.0, dive_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	current_tween.chain().tween_callback(_on_reach_rack)


func _process_dive_steal(_delta: float) -> void:
	if not is_instance_valid(target_rack) or not target_rack.has_fish:
		# Fish was already collected or rack removed
		_abort_to_patrol()
		return

	var player := _get_player()
	if player:
		var dist_to_rack: float = player.global_position.distance_to(target_rack_pos)
		var dist_to_bird: float = player.global_position.distance_to(ground_pos)
		# If player moves close (< 80 pixels) to the rack during the dive, scare away
		if dist_to_rack < 80.0 or dist_to_bird < 75.0:
			_scare_and_abort()
			return


func _scare_and_abort() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_state = State.FLEE
	target_rack = null

	if alert_bubble:
		alert_bubble.visible = false

	# Play startled chirp audio & visual effects
	_play_startled_chirp()

	if squawk_particles:
		squawk_particles.restart()
		squawk_particles.emitting = true

	if animated_sprite:
		animated_sprite.play(&"fly")

	GameEvents.emit_notification("You scared the seagull away in time!")

	var player := _get_player()
	var flee_dir := Vector2(flight_dir, -1.0).normalized()
	if player:
		var away := (ground_pos - player.global_position).normalized()
		flee_dir = Vector2(away.x, -0.6).normalized()
		flight_dir = 1.0 if flee_dir.x >= 0 else -1.0
		if animated_sprite:
			animated_sprite.flip_h = (flight_dir < 0.0)

	var flee_target := ground_pos + flee_dir * 320.0
	var flee_duration: float = 1.5

	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "ground_pos", flee_target, flee_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "altitude", base_patrol_altitude, flee_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.chain().tween_callback(_resume_patrol_after_flee)


func _resume_patrol_after_flee() -> void:
	current_state = State.PATROL
	detect_cooldown = randf_range(3.0, 5.0)
	if animated_sprite:
		animated_sprite.play(&"fly")


func _on_reach_rack() -> void:
	if alert_bubble:
		alert_bubble.visible = false

	if not is_instance_valid(target_rack) or not target_rack.has_fish:
		_abort_to_patrol()
		return

	# Snatch fish from rack
	var stolen: Dictionary = {}
	if target_rack.has_method("snatch_fish"):
		stolen = target_rack.snatch_fish()
	else:
		target_rack.has_fish = false
		target_rack.stored_fish_data = {}
		if target_rack.has_node("%FishDisplaySprite"):
			target_rack.get_node("%FishDisplaySprite").visible = false

	# Ensure rack state and display are cleared
	target_rack.has_fish = false
	if target_rack.has_node("%FishDisplaySprite"):
		target_rack.get_node("%FishDisplaySprite").visible = false

	# Attach fish texture to seagull's beak sprite
	var tex_path: String = stolen.get("texture_path", "")
	var fish_tex: Texture2D = null
	if tex_path != "" and ResourceLoader.exists(tex_path):
		fish_tex = load(tex_path)
	else:
		fish_tex = load("res://sprites/fish/fish-clownfish.png")

	if fish_tex and beak_fish:
		beak_fish.texture = fish_tex
		beak_fish.visible = true
		var max_dim := maxf(fish_tex.get_width(), fish_tex.get_height())
		var b_scale := 20.0 / max_dim if max_dim > 0.0 else 0.02
		beak_fish.scale = Vector2(b_scale, b_scale)

	_update_beak_orientation()

	# Show toast banner
	GameEvents.emit_notification("A seagull snatched your dried fish!")

	# Swoop upward off-screen and despawn
	_swoop_upward_and_despawn()


func _swoop_upward_and_despawn() -> void:
	current_state = State.ESCAPE
	target_rack = null

	if animated_sprite:
		animated_sprite.play(&"fly")
		animated_sprite.flip_h = (flight_dir < 0.0)

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	# Swoop upward off-screen
	var offscreen_x: float = -200.0 if flight_dir < 0.0 else 1850.0
	var offscreen_y: float = ground_pos.y - 280.0
	var offscreen_target := Vector2(offscreen_x, offscreen_y)
	var escape_duration: float = 2.4

	current_tween = create_tween().set_parallel(true)
	current_tween.tween_property(self, "ground_pos", offscreen_target, escape_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	current_tween.tween_property(self, "altitude", 320.0, escape_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	current_tween.chain().tween_callback(func():
		queue_free()
	)


func _update_beak_orientation() -> void:
	if not is_instance_valid(beak_fish):
		return
	if flight_dir < 0.0:
		beak_fish.position = Vector2(-8.0, 6.0)
		beak_fish.flip_h = true
		beak_fish.rotation = -0.4
	else:
		beak_fish.position = Vector2(8.0, 6.0)
		beak_fish.flip_h = false
		beak_fish.rotation = 0.4


func _abort_to_patrol() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	current_state = State.PATROL
	target_rack = null
	if alert_bubble:
		alert_bubble.visible = false
	if animated_sprite:
		animated_sprite.play(&"fly")
	detect_cooldown = 2.0


func _init_chirp_audio() -> void:
	chirp_player = AudioStreamPlayer2D.new()
	add_child(chirp_player)

	# Procedurally generate a startled seagull chirp sound
	var sample_rate: int = 22050
	var duration: float = 0.16
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		# Chirp sweeps up and down: 900Hz -> 1700Hz -> 1000Hz
		var freq: float = 900.0 + 800.0 * sin(PI * (t / duration))
		var envelope: float = sin(PI * (t / duration))
		var sample: float = sin(TAU * freq * t) * envelope * 0.4
		var byte_val: int = clampi(int((sample + 1.0) * 127.5), 0, 255)
		data[i] = byte_val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	chirp_player.stream = wav


func _play_startled_chirp() -> void:
	if chirp_player and chirp_player.stream:
		chirp_player.play()


func _update_transforms() -> void:
	global_position = ground_pos

	if is_instance_valid(flyer_node):
		flyer_node.position = Vector2(0, -altitude)

	if is_instance_valid(ground_shadow):
		var height_factor: float = clampf(1.0 - (altitude / 260.0), 0.15, 1.0)
		ground_shadow.scale = Vector2(height_factor, height_factor * 0.45)
		ground_shadow.color.a = clampf(0.32 * height_factor, 0.06, 0.35)


func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as Node2D
	return null
