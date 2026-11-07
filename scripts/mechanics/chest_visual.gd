class_name ChestVisual
extends Node2D
## Procedural 2D graphics for the coastal fisherman's safe storage chest

func _draw() -> void:
	# 1. Base shadow
	draw_circle(Vector2(0, 4.0), 16.0, Color(0.1, 0.14, 0.18, 0.35))

	# 2. Chest Wooden Body (dark weathered mahogany)
	var body_rect := Rect2(Vector2(-14, -18), Vector2(28, 20))
	draw_rect(body_rect, Color(0.42, 0.28, 0.16, 1.0), true)
	draw_rect(body_rect, Color(0.24, 0.16, 0.08, 1.0), false, 1.2)

	# 3. Wood plank divider lines
	draw_line(Vector2(-14, -11), Vector2(14, -11), Color(0.32, 0.2, 0.12, 1.0), 1.0)
	draw_line(Vector2(-14, -4), Vector2(14, -4), Color(0.32, 0.2, 0.12, 1.0), 1.0)

	# 4. Brass / Iron reinforce bands on sides
	draw_rect(Rect2(Vector2(-13, -18), Vector2(4, 20)), Color(0.72, 0.58, 0.28, 1.0), true)
	draw_rect(Rect2(Vector2(9, -18), Vector2(4, 20)), Color(0.72, 0.58, 0.28, 1.0), true)

	# 5. Center brass lock plate & latch
	draw_rect(Rect2(Vector2(-3, -13), Vector2(6, 8)), Color(0.85, 0.72, 0.32, 1.0), true)
	draw_circle(Vector2(0, -9), 1.6, Color(0.2, 0.15, 0.1, 1.0))

	# 6. Top rounded lid rim
	draw_line(Vector2(-14, -18), Vector2(14, -18), Color(0.55, 0.4, 0.25, 1.0), 2.2)

