class_name FishmongerNPC
extends CharacterBody2D
## Coastal Fishmonger & Trading Shopkeeper: Old Salt Finn
## Positioned on the beach near the shoreline / drying rack / cottage.
## Prompts "Press [E] to Trade" and opens MarketModal.tscn.

signal market_opened()

const MARKET_MODAL_SCENE: PackedScene = preload("res://scenes/ui/MarketModal.tscn")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var shadow: Polygon2D = $Shadow

var player_in_area: bool = false
var active_modal: Node = null


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")

	if anim_sprite:
		anim_sprite.play("idle")

	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "Press [E] to Trade"

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_area or is_instance_valid(active_modal):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			interact()
			get_viewport().set_input_as_handled()


func get_interaction_type() -> String:
	return "npc"


func get_interaction_prompt() -> String:
	return "Press [E] to Trade"


func interact(_player: Node2D = null) -> void:
	if is_instance_valid(active_modal):
		return

	if not MARKET_MODAL_SCENE:
		return

	if prompt_label:
		prompt_label.visible = false

	# Hide global HUD prompt during modal
	GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)

	# Cheerful hop animation
	if anim_sprite:
		var bounce := create_tween()
		bounce.tween_property(anim_sprite, "scale:y", 0.07, 0.08)
		bounce.tween_property(anim_sprite, "scale:y", 0.08, 0.08)

	active_modal = MARKET_MODAL_SCENE.instantiate()
	if active_modal.has_signal("market_closed"):
		active_modal.connect("market_closed", _on_market_closed)
	get_tree().root.add_child(active_modal)
	market_opened.emit()


func _on_market_closed() -> void:
	active_modal = null
	if player_in_area:
		if prompt_label:
			prompt_label.visible = true
		GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		if not is_instance_valid(active_modal):
			if prompt_label:
				prompt_label.visible = true
			GameEvents.interaction_prompt_requested.emit(get_interaction_prompt(), global_position, true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		if prompt_label:
			prompt_label.visible = false
		GameEvents.interaction_prompt_requested.emit("", Vector2.ZERO, false)
