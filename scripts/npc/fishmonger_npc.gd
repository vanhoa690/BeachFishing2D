class_name FishmongerNPC
extends StaticBody2D
## Coastal Fishmonger & Trading Shopkeeper: Old Salt Finn
## Positioned near the shoreline / cottage.
## Prompts "Press [E] to Talk" and opens MarketModal.

signal market_opened()

const MARKET_MODAL_SCENE: PackedScene = preload("res://scenes/ui/MarketModal.tscn")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var nameplate: Label = $Nameplate
@onready var shadow: Polygon2D = $Shadow

var player_in_area: bool = false
var active_modal: MarketModal = null


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")

	if anim_sprite:
		anim_sprite.play("idle")

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)


func get_interaction_type() -> String:
	return "npc"


func get_interaction_prompt() -> String:
	return "Press [E] to Talk"


func interact(_player: Node2D = null) -> void:
	if is_instance_valid(active_modal):
		return

	if not MARKET_MODAL_SCENE:
		return

	# Hide prompt during modal display
	GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)

	# Gentle greeting hop animation
	if anim_sprite:
		var bounce := create_tween()
		bounce.tween_property(anim_sprite, "scale:y", 0.07, 0.08)
		bounce.tween_property(anim_sprite, "scale:y", 0.08, 0.08)

	active_modal = MARKET_MODAL_SCENE.instantiate() as MarketModal
	active_modal.market_closed.connect(_on_market_closed)
	get_tree().root.add_child(active_modal)
	market_opened.emit()


func _on_market_closed() -> void:
	active_modal = null
	if player_in_area:
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		if not is_instance_valid(active_modal):
			GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)

