class_name FishDryingRack
extends StaticBody2D
## Shoreline Fish Drying Rack for "Tide & Hook"
## Allows players to deposit caught fish to cure in the ocean breeze, but exposed to seagulls unless protected!

signal fish_deposited(fish_data: Dictionary)
signal fish_collected(fish_data: Dictionary)
signal fish_stolen_by_seagull(fish_data: Dictionary)

@export var is_safe_storage: bool = false
@export var rack_scale: Vector2 = Vector2(0.038, 0.038)
@export var target_fish_display_size: float = 24.0
@export var fish_display_offset: Vector2 = Vector2(0, -14.0)

var has_fish: bool = false
var stored_fish_data: Dictionary = {}

# Backward compatibility alias
var current_fish: Dictionary:
	get:
		return stored_fish_data
	set(val):
		stored_fish_data = val

@onready var rack_sprite: Sprite2D = $RackSprite
@onready var fish_display_sprite: Sprite2D = %FishDisplaySprite
@onready var fish_display: Sprite2D = %FishDisplaySprite # Alias for any external references
@onready var interaction_area: Area2D = $InteractionArea
@onready var drying_particles: CPUParticles2D = $DryingParticles

var player_in_area: bool = false


func _ready() -> void:
	add_to_group("drying_rack")
	add_to_group("interactable")
	
	if not fish_display_sprite:
		fish_display_sprite = get_node_or_null("FishDisplay")

	if rack_sprite:
		rack_sprite.scale = rack_scale
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	_update_display()


func get_interaction_type() -> String:
	return "drying_rack"


func get_interaction_prompt() -> String:
	if has_fish:
		return "Press [E] to Collect Fish"
	elif GameState.fish_inventory.size() > 0:
		return "Press [E] to Dry Fish"
	else:
		return "No fish in basket"


func interact(_player: Node2D = null) -> void:
	if has_fish:
		_collect_fish()
	elif GameState.fish_inventory.size() > 0:
		_deposit_fish()
	else:
		GameEvents.emit_notification("No fish in basket")


func _deposit_fish() -> void:
	if not GameState.has_fish_in_inventory():
		GameEvents.emit_notification("No fish in basket")
		return

	var fish_entry: Dictionary = GameState.pop_first_fish()
	stored_fish_data = fish_entry
	has_fish = true
	_update_display()

	if drying_particles:
		drying_particles.restart()
		drying_particles.emitting = true

	var name_str: String = fish_entry.get("display_name", "Fish")
	GameEvents.emit_notification("Placed %s on drying rack." % name_str)
	fish_deposited.emit(stored_fish_data)
	GameEvents.drying_rack_interacted.emit(self)

	if player_in_area:
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _collect_fish() -> void:
	if not has_fish:
		return

	var returned_fish: Dictionary = stored_fish_data
	GameState.add_fish_dict_to_inventory(returned_fish)
	has_fish = false
	stored_fish_data = {}
	_update_display()

	var name_str: String = returned_fish.get("display_name", "Fish")
	GameEvents.emit_notification("Collected %s from drying rack." % name_str)
	fish_collected.emit(returned_fish)
	GameEvents.drying_rack_interacted.emit(self)

	if player_in_area:
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func snatch_fish() -> Dictionary:
	if not has_fish or is_safe_storage:
		return {}

	var stolen: Dictionary = stored_fish_data
	has_fish = false
	stored_fish_data = {}
	_update_display()

	fish_stolen_by_seagull.emit(stolen)
	GameEvents.drying_rack_interacted.emit(self)

	if player_in_area:
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)

	return stolen


func _update_display() -> void:
	if not is_instance_valid(fish_display_sprite):
		return

	if has_fish and not stored_fish_data.is_empty():
		var tex_path: String = stored_fish_data.get("texture_path", "")
		if tex_path != "" and ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path)
			fish_display_sprite.texture = tex
			fish_display_sprite.visible = true
			fish_display_sprite.z_index = 1
			fish_display_sprite.position = fish_display_offset

			# Dynamically scale to fit neatly within the target ~24x24 px display box
			var tex_size := tex.get_size()
			var max_dim := maxf(tex_size.x, tex_size.y)
			var target_scale: Vector2
			if max_dim > 0.0:
				var s: float = target_fish_display_size / max_dim
				target_scale = Vector2(s, s)
			else:
				target_scale = Vector2(0.015, 0.015)

			fish_display_sprite.scale = target_scale
			# Animate gentle placement pop
			var pop_scale: Vector2 = target_scale * 1.2
			var tween := create_tween()
			tween.tween_property(fish_display_sprite, "scale", pop_scale, 0.15).set_trans(Tween.TRANS_BACK)
			tween.tween_property(fish_display_sprite, "scale", target_scale, 0.1)
		else:
			fish_display_sprite.visible = false
			fish_display_sprite.texture = null
	else:
		fish_display_sprite.visible = false
		fish_display_sprite.texture = null


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)
