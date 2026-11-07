class_name BaitPopEffect
extends Node2D
## Visual pop & float effect when a worm is unearthed.
## Arches upward, wriggles, floats to the player, awards bait to GameState, and frees itself.

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Polygon2D = $Shadow

var worm_amount: int = 1
var target_character: Node2D = null


func _ready() -> void:
	if animated_sprite:
		animated_sprite.play(&"wriggle")


func launch(amount: int, target_node: Node2D = null) -> void:
	worm_amount = amount
	target_character = target_node

	var start_pos := global_position
	var lateral_offset := randf_range(-14.0, 14.0)
	var peak_height := randf_range(20.0, 25.0)
	var peak_pos := start_pos + Vector2(lateral_offset, -peak_height)

	# Initial scale setup
	scale = Vector2(0.4, 0.4)

	# Phase 1: Pop / Arch Upward
	var pop_tween := create_tween().set_parallel(true)
	pop_tween.tween_property(self, "global_position:y", peak_pos.y, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "global_position:x", peak_pos.x, 0.26).set_trans(Tween.TRANS_LINEAR)
	pop_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shadow:
		pop_tween.tween_property(shadow, "scale", Vector2(0.5, 0.5), 0.26)
		pop_tween.tween_property(shadow, "modulate:a", 0.2, 0.26)

	# Phase 2: Float toward Player
	pop_tween.chain().set_parallel(false)
	var float_duration := 0.36
	
	var float_tween := create_tween().set_parallel(true)
	var dest_pos := start_pos + Vector2(lateral_offset, 2.0)
	if is_instance_valid(target_character):
		dest_pos = target_character.global_position + Vector2(0, -8)

	float_tween.tween_property(self, "global_position", dest_pos, float_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	float_tween.tween_property(self, "scale", Vector2(0.75, 0.75), float_duration)
	float_tween.tween_property(self, "modulate:a", 0.0, 0.12).set_delay(float_duration - 0.12)
	
	float_tween.chain().tween_callback(_on_reached_destination)


func _on_reached_destination() -> void:
	# Increment the bait counter upon reaching the player
	GameState.add_worms(worm_amount)
	
	# Emit notification & floating text
	var text_pos := global_position
	if is_instance_valid(target_character):
		text_pos = target_character.global_position + Vector2(0, -14)
	
	GameEvents.worm_dug.emit(worm_amount, text_pos)
	queue_free()

