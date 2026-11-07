class_name FishDryingRack
extends StaticBody2D
## Shoreline Fish Drying Rack for "Tide & Hook"
## Allows players to deposit caught fish to cure in the ocean breeze, but exposed to seagulls unless protected!

signal fish_deposited(fish_data: Dictionary)
signal fish_collected(fish_data: Dictionary)
signal fish_stolen_by_seagull(fish_data: Dictionary)

@export var is_safe_storage: bool = false
@export var rack_scale: Vector2 = Vector2(0.038, 0.038)

var has_fish: bool = false
var current_fish: Dictionary = {}

@onready var rack_sprite: Sprite2D = $RackSprite
@onready var fish_display: Sprite2D = $FishDisplay
@onready var interaction_area: Area2D = $InteractionArea
@onready var drying_particles: CPUParticles2D = $DryingParticles


func _ready() -> void:
	add_to_group("drying_rack")
	add_to_group("interactable")
	
	if rack_sprite:
		rack_sprite.scale = rack_scale
	
	_update_display()


func get_interaction_type() -> String:
	return "drying_rack"


func get_interaction_prompt() -> String:
	if has_fish:
		var name_str: String = current_fish.get("display_name", "Fish")
		return "Press [E] / [Space] to Collect %s" % name_str
	elif GameState.has_fish_in_inventory():
		var first_fish: Dictionary = GameState.fish_inventory[0]
		return "Press [E] / [Space] to Dry Fish (%s)" % first_fish.get("display_name", "Fish")
	else:
		return "Empty Drying Rack (No fish in basket)"


func interact(_player: Node2D) -> void:
	if has_fish:
		_collect_fish()
	else:
		_deposit_fish()


func _deposit_fish() -> void:
	if not GameState.has_fish_in_inventory():
		GameEvents.emit_notification("No fish in basket to dry! Catch some fish first.")
		return

	var fish_entry: Dictionary = GameState.pop_first_fish()
	current_fish = fish_entry
	has_fish = true
	_update_display()

	if drying_particles:
		drying_particles.restart()
		drying_particles.emitting = true

	var name_str: String = fish_entry.get("display_name", "Fish")
	GameEvents.emit_notification("Placed %s on drying rack." % name_str)
	fish_deposited.emit(current_fish)
	GameEvents.drying_rack_interacted.emit(self)


func _collect_fish() -> void:
	if not has_fish:
		return

	var returned_fish: Dictionary = current_fish
	GameState.add_fish_dict_to_inventory(returned_fish)
	has_fish = false
	current_fish = {}
	_update_display()

	var name_str: String = returned_fish.get("display_name", "Fish")
	GameEvents.emit_notification("Collected %s from drying rack." % name_str)
	fish_collected.emit(returned_fish)
	GameEvents.drying_rack_interacted.emit(self)


func snatch_fish() -> Dictionary:
	if not has_fish or is_safe_storage:
		return {}

	var stolen: Dictionary = current_fish
	has_fish = false
	current_fish = {}
	_update_display()

	fish_stolen_by_seagull.emit(stolen)
	GameEvents.drying_rack_interacted.emit(self)
	return stolen


func _update_display() -> void:
	if not is_instance_valid(fish_display):
		return

	if has_fish and not current_fish.is_empty():
		var tex_path: String = current_fish.get("texture_path", "")
		if tex_path != "" and ResourceLoader.exists(tex_path):
			fish_display.texture = load(tex_path)
			fish_display.visible = true
			fish_display.scale = Vector2(0.045, 0.045)
			# Animate gentle placement pop
			var tween := create_tween()
			tween.tween_property(fish_display, "scale", Vector2(0.05, 0.05), 0.15).set_trans(Tween.TRANS_BACK)
			tween.tween_property(fish_display, "scale", Vector2(0.045, 0.045), 0.1)
		else:
			fish_display.visible = false
	else:
		fish_display.visible = false

