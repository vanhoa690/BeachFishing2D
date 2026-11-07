class_name AlertBubble
extends Node2D
## Animated exclamation bubble ("!") appearing above the bobber when a fish strikes

@export var bubble_color: Color = Color(1.0, 0.28, 0.2, 0.95)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var exclamation_color: Color = Color(1.0, 1.0, 1.0, 1.0)


func _draw() -> void:
	# Circular pill / bubble
	var radius: float = 10.0
	draw_circle(Vector2(0, 0), radius + 1.5, border_color)
	draw_circle(Vector2(0, 0), radius, bubble_color)

	# Small pointer triangle at bottom pointing towards bobber
	var tail_pts := PackedVector2Array([
		Vector2(-4.0, 8.0),
		Vector2(4.0, 8.0),
		Vector2(0.0, 14.0)
	])
	draw_colored_polygon(tail_pts, bubble_color)
	draw_polyline(PackedVector2Array([Vector2(-4.0, 8.0), Vector2(0.0, 14.0), Vector2(4.0, 8.0)]), border_color, 1.5)

	# Bold exclamation mark: vertical stroke and dot
	draw_line(Vector2(0, -5.5), Vector2(0, 1.0), exclamation_color, 2.5)
	draw_circle(Vector2(0, 4.5), 1.4, exclamation_color)

