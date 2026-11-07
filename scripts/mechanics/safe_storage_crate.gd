class_name SafeStorageCrate
extends StaticBody2D
## Safe Cottage Storage Crate for "Tide & Hook"
## A secure wooden coastal storage chest where fish are 100% safe from hungry seagulls.

signal fish_stored(fish_data: Dictionary)
signal fish_retrieved(fish_data: Dictionary)

@export var is_safe_storage: bool = true

var stored_fish: Array[Dictionary] = []

@onready var chest_visual: Node2D = $ChestVisual
@onready var count_badge: Label = $CountBadge
@onready var puff_particles: CPUParticles2D = $PuffParticles


func _ready() -> void:
	add_to_group("safe_storage")
	add_to_group("interactable")
	_update_badge()


func get_interaction_type() -> String:
	return "safe_storage"


func get_interaction_prompt() -> String:
	if not stored_fish.is_empty():
		var top_fish: Dictionary = stored_fish.back()
		return "Press [E] / [Space] to Retrieve %s (%d Safe)" % [top_fish.get("display_name", "Fish"), stored_fish.size()]
	elif GameState.has_fish_in_inventory():
		var player_fish: Dictionary = GameState.fish_inventory[0]
		return "Press [E] / [Space] to Store %s Safely (Seagull-Proof)" % player_fish.get("display_name", "Fish")
	else:
		return "Safe Cottage Storage (0 Fish - Seagull Proof)"


func interact(_player: Node2D) -> void:
	if not stored_fish.is_empty():
		_retrieve_fish()
	elif GameState.has_fish_in_inventory():
		_deposit_fish()
	else:
		GameEvents.emit_notification("Your fish basket is empty! Nothing to store.")


func _deposit_fish() -> void:
	if not GameState.has_fish_in_inventory():
		return

	var fish_entry: Dictionary = GameState.pop_first_fish()
	stored_fish.append(fish_entry)
	_update_badge()

	if puff_particles:
		puff_particles.restart()
		puff_particles.emitting = true

	var name_str: String = fish_entry.get("display_name", "Fish")
	GameEvents.emit_notification("Stored %s in safe cottage crate (Protected from seagulls)." % name_str)
	fish_stored.emit(fish_entry)


func _retrieve_fish() -> void:
	if stored_fish.is_empty():
		return

	var fish_entry: Dictionary = stored_fish.pop_back()
	GameState.add_fish_dict_to_inventory(fish_entry)
	_update_badge()

	if puff_particles:
		puff_particles.restart()
		puff_particles.emitting = true

	var name_str: String = fish_entry.get("display_name", "Fish")
	GameEvents.emit_notification("Retrieved %s from safe cottage crate." % name_str)
	fish_retrieved.emit(fish_entry)


func _update_badge() -> void:
	if is_instance_valid(count_badge):
		var count: int = stored_fish.size()
		if count > 0:
			count_badge.text = "🔒 %d" % count
			count_badge.visible = true
		else:
			count_badge.visible = false

