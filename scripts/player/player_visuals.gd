extends Node2D
## Procedural Cozy Visuals for Player Character
## Renders stylized coastal fisherman with smooth walk cycle and tool handling.

@export var body_color: Color = Color(0.96, 0.72, 0.15) # Yellow oilskin raincoat
@export var hat_color: Color = Color(0.22, 0.28, 0.35) # Dark slate sou'wester hat
@export var skin_color: Color = Color(0.98, 0.84, 0.72) # Warm skin tone
@export var boot_color: Color = Color(0.18, 0.18, 0.20) # Dark rubber boots

var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var is_digging: bool = false
var walk_cycle: float = 0.0
var dig_progress: float = 0.0
var current_tool: int = 1 # GameState.ToolType.SHOVEL by default


func _process(delta: float) -> void:
	if is_digging:
		# Digging animation handled by tween/timer
		queue_redraw()
		return

	if is_moving:
		walk_cycle += delta * 12.0
	else:
		walk_cycle = move_toward(walk_cycle, 0.0, delta * 8.0)
	
	queue_redraw()


func play_dig_animation(duration: float = 0.45) -> void:
	is_digging = true
	dig_progress = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "dig_progress", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		is_digging = false
		dig_progress = 0.0
		queue_redraw()
	)


func set_tool(tool_type: int) -> void:
	current_tool = tool_type
	queue_redraw()


func _draw() -> void:
	var bob_offset: float = sin(walk_cycle) * 2.0 if is_moving else 0.0
	var step_tilt: float = cos(walk_cycle) * 0.08 if is_moving else 0.0
	var tilt_x: float = step_tilt * 12.0
	
	# 1. Soft Drop Shadow
	draw_circle(Vector2(0, 10), 12.0, Color(0.08, 0.12, 0.18, 0.28))

	# 2. Rubber Boots / Feet
	var left_foot_offset: float = sin(walk_cycle) * 3.0 if is_moving else 0.0
	var right_foot_offset: float = -sin(walk_cycle) * 3.0 if is_moving else 0.0
	draw_circle(Vector2(-5, 9 + left_foot_offset), 3.5, boot_color)
	draw_circle(Vector2(5, 9 + right_foot_offset), 3.5, boot_color)

	# 3. Torso / Raincoat (with dynamic walk step tilt)
	var body_rect := Rect2(-8 + tilt_x * 0.35, -6 + bob_offset, 16, 14)
	draw_rect(body_rect, body_color, true)
	# Raincoat collar / trim
	draw_line(Vector2(tilt_x * 0.35, -6 + bob_offset), Vector2(tilt_x * 0.35, 6 + bob_offset), body_color.darkened(0.2), 2.0)
	# Raincoat toggle buttons
	draw_circle(Vector2(tilt_x * 0.35, -2 + bob_offset), 1.2, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(tilt_x * 0.35, 2 + bob_offset), 1.2, Color(0.1, 0.1, 0.1))

	# 4. Head & Face
	var head_center := Vector2(tilt_x * 0.7, -11 + bob_offset)
	draw_circle(head_center, 7.0, skin_color)

	# Eyes depending on facing direction
	var eye_offset: Vector2 = facing_direction.normalized() * 2.5
	if facing_direction.y < -0.5:
		# Facing up: back of head, no eyes
		pass
	elif abs(facing_direction.x) > 0.5:
		# Facing side
		var eye_x: float = 2.5 if facing_direction.x > 0 else -2.5
		draw_circle(head_center + Vector2(eye_x, -0.5), 1.2, Color(0.15, 0.15, 0.18))
		# Rosy cheek
		draw_circle(head_center + Vector2(eye_x, 1.8), 1.5, Color(1.0, 0.55, 0.55, 0.5))
	else:
		# Facing down / front
		draw_circle(head_center + Vector2(-2.5, -0.5) + eye_offset * 0.4, 1.2, Color(0.15, 0.15, 0.18))
		draw_circle(head_center + Vector2(2.5, -0.5) + eye_offset * 0.4, 1.2, Color(0.15, 0.15, 0.18))
		# Rosy cheeks
		draw_circle(head_center + Vector2(-3.5, 1.8), 1.5, Color(1.0, 0.55, 0.55, 0.5))
		draw_circle(head_center + Vector2(3.5, 1.8), 1.5, Color(1.0, 0.55, 0.55, 0.5))

	# 5. Cozy Fisherman Beanie / Sou'wester Hat
	var hat_pos := head_center + Vector2(0, -3)
	draw_circle(hat_pos + Vector2(0, -2), 6.5, hat_color)
	draw_line(hat_pos + Vector2(-8, 1), hat_pos + Vector2(8, 1), hat_color.darkened(0.15), 3.0)

	# 6. Held Tool Drawing
	_draw_held_tool(bob_offset)


func _draw_held_tool(bob: float) -> void:
	if current_tool == 0:
		return # Bare hands

	var tool_root: Vector2
	var tool_angle: float = 0.0

	# Hand anchor point based on facing direction
	if facing_direction.x > 0.3:
		tool_root = Vector2(8, 2 + bob)
		tool_angle = 0.35
	elif facing_direction.x < -0.3:
		tool_root = Vector2(-8, 2 + bob)
		tool_angle = -0.35
	elif facing_direction.y < -0.3:
		tool_root = Vector2(7, -4 + bob)
		tool_angle = -1.2
	else:
		tool_root = Vector2(7, 3 + bob)
		tool_angle = 0.25

	if is_digging:
		# Digging scoop arc
		var dig_swing: float = sin(dig_progress * PI) * 1.2
		tool_angle += dig_swing
		tool_root.y += sin(dig_progress * PI) * 8.0

	# Draw Hand
	draw_circle(tool_root, 2.5, skin_color)

	# Draw Tool
	if current_tool == 1: # Shovel
		_draw_shovel(tool_root, tool_angle)
	elif current_tool == 2: # Fishing Rod
		_draw_rod(tool_root, tool_angle)


func _draw_shovel(root: Vector2, angle: float) -> void:
	var dir := Vector2.DOWN.rotated(angle)
	var handle_length: float = 16.0
	var tip: Vector2 = root + dir * handle_length

	# Wooden Handle
	draw_line(root, tip, Color(0.55, 0.35, 0.2), 2.2)
	# Wooden T-grip
	var perp := dir.orthogonal() * 2.8
	draw_line(root - perp, root + perp, Color(0.45, 0.28, 0.15), 2.5)
	# Metallic Blade / Spade
	var spade_start := tip - dir * 2.0
	var spade_p1 := tip + perp * 3.5
	var spade_p2 := tip - perp * 3.5
	var spade_tip := tip + dir * 6.0
	var spade_points := PackedVector2Array([spade_start, spade_p1, spade_tip, spade_p2])
	draw_colored_polygon(spade_points, Color(0.72, 0.76, 0.8))
	draw_polyline(spade_points, Color(0.4, 0.44, 0.5), 1.0)


func _draw_rod(root: Vector2, angle: float) -> void:
	var dir := Vector2.UP.rotated(angle + 0.3)
	var tip: Vector2 = root + dir * 22.0
	# Bamboo Rod Shaft
	draw_line(root, tip, Color(0.78, 0.62, 0.35), 2.0)
	# Grip
	draw_line(root, root + dir * 5.0, Color(0.3, 0.2, 0.15), 2.8)
	# Small guide rings
	draw_circle(root + dir * 10.0, 1.2, Color(0.85, 0.85, 0.85))
	draw_circle(root + dir * 16.0, 1.2, Color(0.85, 0.85, 0.85))
	draw_circle(tip, 1.5, Color(0.9, 0.2, 0.2)) # Red tip
	# Fishing Line hanging loose
	var line_end := tip + Vector2(2, 12)
	draw_line(tip, line_end, Color(0.95, 0.95, 0.95, 0.6), 1.0)

