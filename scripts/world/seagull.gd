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
var detect_cooldown: float = 1.8

@onready var flyer_node: Node2D = $FlyerNode
@onready var animated_sprite: AnimatedSprite2D = $FlyerNode/AnimatedSprite2D
@onready var alert_bubble: Node2D = $FlyerNode/AlertMark
@onready var beak_fish: Sprite2D = $FlyerNode/BeakFish
@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var squawk_particles: CPUParticles2D = $FlyerNode/SquawkParticles


func _ready() -> void:
	ground_pos = global_position
	altitude = base_patrol_altitude
	flight_dir = 1.0 if randf() > 0.5 else -1.0

	if animated_sprite:
		animated_sprite.play(&"fly")
	if alert_bubble:
		alert_bubble.visible = false
	if beak_fish:
		beak_fish.visible = false

	_update_transforms()


func _physics_process(delta: float) -> void:
	time_alive += delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.DIVE_STEAL:
			_process_dive_steal(delta)
		State.FLEE:
			_process_flee(delta)
		State.ESCAPE:
			_process_escape(delta)

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
		detect_cooldown = randf_range(1.6, 2.8)
		_scan_for_drying_racks()


func _scan_for_drying_racks() -> void:
	var racks: Array[Node] = get_tree().get_nodes_in_group("drying_rack")
	if racks.is_empty():
		return

	var player = _get_player()
	if not player:
		return

	# Shuffle or pick first valid rack with fish
	for node in racks:
		var rack := node as FishDryingRack
		if not rack or not is_instance_valid(rack):
			continue

		# Only target racks that have a fish and are NOT inside safe storage
		if rack.has_fish and not rack.is_safe_storage:
			var player_dist: float = player.global_position.distance_to(rack.global_position)
			# Only dive if player is distracted or far (> 160px away)
			if player_dist > 160.0:
				_start_dive(rack)
				break


func _start_dive(rack: FishDryingRack) -> void:
	target_rack = rack
	target_rack_pos = rack.global_position
	current_state = State.DIVE_STEAL

	if animated_sprite:
		animated_sprite.play(&"dive")
		animated_sprite.flip_h = (target_rack_pos.x < ground_pos.x)

	if alert_bubble:
		alert_bubble.visible = true
		alert_bubble.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(alert_bubble, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK)
		tween.tween_property(alert_bubble, "scale", Vector2.ONE, 0.1)


func _process_dive_steal(delta: float) -> void:
	if not is_instance_valid(target_rack) or not target_rack.has_fish:
		# Fish was already collected or rack gone
		_abort_to_patrol()
		return

	var player = _get_player()
	if player:
		var player_dist_to_rack: float = player.global_position.distance_to(target_rack_pos)
		var player_dist_to_bird: float = player.global_position.distance_to(ground_pos)
		# If player charges close to protect the rack (< 90px), scare seagull away!
		if player_dist_to_rack < 90.0 or player_dist_to_bird < 85.0:
			_flee_from_player()
			return

	# Swoop ground position toward rack
	ground_pos = ground_pos.move_toward(target_rack_pos, dive_speed * delta)
	# Descend altitude rapidly toward rack surface (altitude ~18px)
	altitude = move_toward(altitude, 18.0, 110.0 * delta)

	var ground_dist: float = ground_pos.distance_to(target_rack_pos)
	if ground_dist < 12.0 and altitude <= 24.0:
		# Snatch the fish!
		_snatch_fish()


func _snatch_fish() -> void:
	if alert_bubble:
		alert_bubble.visible = false

	if is_instance_valid(target_rack) and target_rack.has_fish:
		var stolen: Dictionary = target_rack.snatch_fish()
		if not stolen.is_empty():
			# Attach fish texture to beak
			if beak_fish:
				var tex_path: String = stolen.get("texture_path", "")
				if tex_path != "" and ResourceLoader.exists(tex_path):
					beak_fish.texture = load(tex_path)
					beak_fish.visible = true
			GameEvents.emit_notification("A cheeky seagull snatched the fish from the drying rack!")

	current_state = State.ESCAPE
	if animated_sprite:
		animated_sprite.play(&"fly")


func _flee_from_player() -> void:
	current_state = State.FLEE
	target_rack = null

	if alert_bubble:
		alert_bubble.visible = false

	if squawk_particles:
		squawk_particles.restart()
		squawk_particles.emitting = true

	if animated_sprite:
		animated_sprite.play(&"fly")

	GameEvents.emit_notification("You scared the seagull away in time!")


func _process_flee(delta: float) -> void:
	# Rapid climb and fly away from player
	altitude += 130.0 * delta

	var player = _get_player()
	var flee_vector := Vector2.UP
	if player:
		flee_vector = (ground_pos - player.global_position).normalized()
	
	ground_pos += flee_vector * flee_speed * delta

	if animated_sprite:
		animated_sprite.flip_h = (flee_vector.x < 0.0)

	# Once high enough, resume cruising
	if altitude >= base_patrol_altitude + 20.0:
		current_state = State.PATROL
		detect_cooldown = 3.5


func _process_escape(delta: float) -> void:
	# Fly away with the stolen prize
	altitude += 90.0 * delta
	ground_pos.x += flight_speed * 1.5 * flight_dir * delta
	ground_pos.y -= 45.0 * delta

	if altitude >= 260.0:
		# Reset seagull on other side of map without fish
		beak_fish.visible = false
		altitude = base_patrol_altitude
		ground_pos.y = randf_range(200.0, 700.0)
		ground_pos.x = 400.0 if flight_dir > 0 else 1400.0
		current_state = State.PATROL
		detect_cooldown = 4.0


func _abort_to_patrol() -> void:
	current_state = State.PATROL
	target_rack = null
	if alert_bubble:
		alert_bubble.visible = false
	detect_cooldown = 2.0


func _update_transforms() -> void:
	global_position = ground_pos

	if is_instance_valid(flyer_node):
		flyer_node.position = Vector2(0, -altitude)

	if is_instance_valid(ground_shadow):
		# Ground shadow shrinks and fades with altitude
		var height_factor: float = clampf(1.0 - (altitude / 260.0), 0.15, 1.0)
		ground_shadow.scale = Vector2(height_factor, height_factor * 0.45)
		ground_shadow.color.a = clampf(0.32 * height_factor, 0.06, 0.35)


func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as Node2D
	return null

