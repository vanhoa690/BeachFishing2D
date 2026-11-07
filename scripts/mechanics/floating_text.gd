class_name FloatingText
extends Node2D
## Floating text popup for loot notifications and feedback.

@onready var label: Label = $Label


func setup(text: String, text_color: Color = Color(1.0, 0.85, 0.45)) -> void:
	if not label:
		label = $Label
	label.text = text
	label.modulate = text_color
	
	# Animate float and fade
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 32.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.finished.connect(queue_free)

