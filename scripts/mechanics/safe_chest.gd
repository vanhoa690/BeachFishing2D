class_name SafeChest
extends StaticBody2D
## Safe Fisherman's Storage Chest for "Tide & Hook"
## Interacting opens the SafeChestModal. Stored fish are 100% immune to seagulls.

signal chest_opened()

@export var is_safe_storage: bool = true

const MODAL_SCENE: PackedScene = preload("res://scenes/ui/safe_chest_modal.tscn")

@onready var chest_visual: Node2D = $ChestVisual
@onready var count_badge: Label = $CountBadge
@onready var puff_particles: CPUParticles2D = $PuffParticles
@onready var interaction_area: Area2D = $InteractionArea

var player_in_area: bool = false


func _ready() -> void:
	add_to_group("safe_storage")
	add_to_group("interactable")
	GameEvents.chest_storage_changed.connect(_on_storage_changed)
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		
	_update_badge()


func get_interaction_type() -> String:
	return "safe_storage"


func get_interaction_prompt() -> String:
	var count: int = GameState.chest_storage.size()
	if count > 0:
		return "Press [E] to Open Safe Storage Chest (%d Fish Stored)" % count
	return "Press [E] to Open Safe Storage Chest (Seagull-Proof 🔒)"


func interact(_player: Node2D = null) -> void:
	if not MODAL_SCENE:
		return

	if puff_particles:
		puff_particles.restart()
		puff_particles.emitting = true

	var modal = MODAL_SCENE.instantiate()
	get_tree().root.add_child(modal)
	chest_opened.emit()


func _on_storage_changed(_items: Array) -> void:
	_update_badge()
	if player_in_area:
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _update_badge() -> void:
	if is_instance_valid(count_badge):
		var count: int = GameState.chest_storage.size()
		if count > 0:
			count_badge.text = "🔒 %d" % count
			count_badge.visible = true
		else:
			count_badge.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)

