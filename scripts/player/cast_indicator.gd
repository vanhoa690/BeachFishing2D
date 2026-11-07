class_name CastIndicator
extends Node2D
## Visual aiming reticle and cast power meter for "Tide & Hook"

var is_active: bool = false
var start_point: Vector2 = Vector2.ZERO
var target_point: Vector2 = Vector2.ZERO
var power_ratio: float = 0.0 # 0.0 to 1.0
var anim_phase: float = 0.0


func _process(delta: float) -> void:
	if is_active:
		anim_phase += delta * 6.0
		queue_redraw()


func start_aiming() -> void:
	is_active = true
	anim_phase = 0.0
	visible = true
	queue_redraw()


func update_aim(from_pos: Vector2, to_pos: Vector2, ratio: float) -> void:
	start_point = to_local(from_pos)
	target_point = to_local(to_pos)
	power_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func stop_aiming() -> void:
	is_active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	# 1. Dotted parabolic trajectory arc to target
	var num_dots: int = 14
	var arc_height: float = 38.0
	for i in range(num_dots + 1):
		var t: float = float(i) / float(num_dots)
		var pt: Vector2 = start_point.lerp(target_point, t)
		var height_offset: float = -4.0 * arc_height * t * (1.0 - t)
		pt.y += height_offset

		# Moving pulse along the dots
		var dot_phase: float = fposmod(anim_phase - float(i) * 0.4, 2.0 * PI)
		var dot_radius: float = 1.8 + sin(dot_phase) * 0.6
		var dot_alpha: float = 0.5 + sin(dot_phase) * 0.4
		draw_circle(pt, dot_radius, Color(0.85, 0.95, 1.0, dot_alpha))

	# 2. Water target ripple ring at landing position
	var ripple_radius: float = 12.0 + sin(anim_phase * 0.8) * 3.0
	draw_arc(target_point, ripple_radius, 0.0, TAU, 24, Color(0.3, 0.85, 1.0, 0.8), 1.8)
	draw_arc(target_point, ripple_radius * 0.6, 0.0, TAU, 18, Color(0.7, 0.95, 1.0, 0.6), 1.2)
	draw_circle(target_point, 3.0, Color(1.0, 0.85, 0.3, 0.9))

	# 3. Compact Floating Power Bar above player
	var bar_pos: Vector2 = Vector2(-22.0, -38.0)
	var bar_width: float = 44.0
	var bar_height: float = 6.0

	# Dark background
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), Color(0.1, 0.12, 0.16, 0.88), true)
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), Color(0.4, 0.5, 0.6, 0.8), false, 1.0)

	# Power Fill (Color blends from Cyan to Gold to Orange)
	var fill_color: Color = Color(0.3, 0.85, 0.5).lerp(Color(1.0, 0.8, 0.2), power_ratio)
	if power_ratio > 0.8:
		fill_color = Color(1.0, 0.8, 0.2).lerp(Color(1.0, 0.35, 0.2), (power_ratio - 0.8) / 0.2)
	
	var fill_w: float = maxf(2.0, bar_width * power_ratio)
	draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_height)), fill_color, true)

