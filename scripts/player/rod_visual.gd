class_name RodVisual
extends Node2D
## Visual bamboo fishing rod rendered in the player's hands

var is_visible: bool = false
var facing_dir: Vector2 = Vector2.DOWN
var rod_bend: float = 0.0 # Bending flex of the rod


func update_rod(visible_state: bool, direction: Vector2, bend_amount: float = 0.0) -> void:
	is_visible = visible_state
	facing_dir = direction
	rod_bend = bend_amount
	visible = is_visible
	queue_redraw()


func _draw() -> void:
	if not is_visible:
		return

	var base_offset: Vector2 = Vector2.ZERO
	var tip_offset: Vector2 = Vector2.ZERO

	if abs(facing_dir.x) > abs(facing_dir.y):
		if facing_dir.x < 0: # Left (toward ocean)
			base_offset = Vector2(-4.0, -8.0)
			tip_offset = Vector2(-28.0, -18.0 + rod_bend * 6.0)
		else: # Right
			base_offset = Vector2(4.0, -8.0)
			tip_offset = Vector2(28.0, -18.0 + rod_bend * 6.0)
	else:
		if facing_dir.y > 0: # Down
			base_offset = Vector2(5.0, -6.0)
			tip_offset = Vector2(16.0, 14.0 + rod_bend * 5.0)
		else: # Up
			base_offset = Vector2(-5.0, -12.0)
			tip_offset = Vector2(-16.0, -28.0 + rod_bend * 5.0)

	var mid_offset: Vector2 = base_offset.lerp(tip_offset, 0.5) + Vector2(0, rod_bend * 4.0)

	# 1. Bamboo Pole curve (3-point line)
	var bamboo_color := Color(0.82, 0.74, 0.42, 1.0)
	var joint_color := Color(0.45, 0.35, 0.2, 1.0)

	# Lower half (thicker)
	draw_line(base_offset, mid_offset, bamboo_color, 2.6)
	# Upper half (tapered)
	draw_line(mid_offset, tip_offset, bamboo_color, 1.6)

	# Bamboo node rings
	var node1: Vector2 = base_offset.lerp(tip_offset, 0.3)
	var node2: Vector2 = base_offset.lerp(tip_offset, 0.65)
	draw_circle(node1, 1.8, joint_color)
	draw_circle(node2, 1.4, joint_color)

	# Rod tip guide ring
	draw_circle(tip_offset, 1.6, Color(0.95, 0.85, 0.4, 1.0))

