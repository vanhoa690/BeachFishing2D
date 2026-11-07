class_name BobberVisual
extends Node2D
## Procedural 2D graphics for the classic red-and-white fishing bobber

@export var radius: float = 6.0


func _draw() -> void:
	# 1. Water shadow
	draw_circle(Vector2(0, 4.0), radius * 0.9, Color(0.04, 0.12, 0.2, 0.35))

	# 2. White lower float dome
	draw_circle(Vector2(0, 0), radius, Color(0.95, 0.95, 0.97, 1.0))
	
	# 3. Red upper float dome (semi-circle on top)
	var red_pts := PackedVector2Array()
	red_pts.append(Vector2(-radius, 0))
	for i in range(17):
		var angle: float = PI + (float(i) / 16.0) * PI
		red_pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	red_pts.append(Vector2(radius, 0))
	draw_colored_polygon(red_pts, Color(0.92, 0.22, 0.2, 1.0))

	# 4. Center black dividing band
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(0.18, 0.18, 0.2, 1.0), 1.2)

	# 5. Top antenna stick
	draw_line(Vector2(0, -radius), Vector2(0, -radius - 7.0), Color(0.3, 0.22, 0.15, 1.0), 1.5)
	
	# 6. High-visibility orange tip bead
	draw_circle(Vector2(0, -radius - 7.0), 2.2, Color(1.0, 0.45, 0.1, 1.0))

