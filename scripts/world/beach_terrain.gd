class_name BeachTerrain
extends Node2D
## Procedurally renders the cozy coastal sand flats, dunes, shells, and shoreline.

@export var beach_width: float = 1600.0
@export var beach_height: float = 1000.0

# Coastal color palette
const COLOR_DEEP_WATER := Color(0.12, 0.35, 0.58)
const COLOR_SHALLOW_WATER := Color(0.25, 0.62, 0.75, 0.7)
const COLOR_WET_SAND := Color(0.78, 0.68, 0.48)
const COLOR_DRY_SAND := Color(0.93, 0.84, 0.63)
const COLOR_DUNES := Color(0.88, 0.78, 0.56)
const COLOR_FOAM := Color(0.95, 0.98, 1.0, 0.8)

var shells: Array[Dictionary] = []
var rocks: Array[Dictionary] = []


func _ready() -> void:
	# Deterministic random generation for shells and rocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 4289
	
	# Generate coastal shells
	for i in range(28):
		shells.append({
			"pos": Vector2(rng.randf_range(100, beach_width - 100), rng.randf_range(200, beach_height - 100)),
			"size": rng.randf_range(2.0, 4.0),
			"color": Color(rng.randf_range(0.92, 1.0), rng.randf_range(0.85, 0.95), rng.randf_range(0.85, 0.95))
		})
		
	# Generate decorative coastal pebbles
	for i in range(35):
		rocks.append({
			"pos": Vector2(rng.randf_range(80, beach_width - 80), rng.randf_range(150, beach_height - 80)),
			"size": rng.randf_range(3.0, 6.5),
			"color": Color(rng.randf_range(0.5, 0.65), rng.randf_range(0.48, 0.6), rng.randf_range(0.45, 0.55))
		})

	queue_redraw()


func _draw() -> void:
	# 1. Base Sand
	draw_rect(Rect2(0, 0, beach_width, beach_height), COLOR_DRY_SAND)

	# 2. Upper Grassy Dunes
	var dune_points := PackedVector2Array([
		Vector2(0, 0),
		Vector2(beach_width, 0),
		Vector2(beach_width, 90),
		Vector2(beach_width * 0.75, 110),
		Vector2(beach_width * 0.5, 85),
		Vector2(beach_width * 0.25, 115),
		Vector2(0, 95)
	])
	draw_colored_polygon(dune_points, Color(0.45, 0.65, 0.35)) # Coastal dune grass
	# Dune sand transition
	var dune_sand := PackedVector2Array([
		Vector2(0, 95),
		Vector2(beach_width * 0.25, 115),
		Vector2(beach_width * 0.5, 85),
		Vector2(beach_width * 0.75, 110),
		Vector2(beach_width, 90),
		Vector2(beach_width, 130),
		Vector2(0, 130)
	])
	draw_colored_polygon(dune_sand, COLOR_DUNES)

	# 3. Lower Shoreline & Wet Sand Transition (leading to water)
	var wet_sand_top: float = beach_height - 220.0
	var wet_sand_rect := Rect2(0, wet_sand_top, beach_width, 220.0)
	draw_rect(wet_sand_rect, COLOR_WET_SAND)

	# 4. Coastal Water Shoreline
	var water_top: float = beach_height - 120.0
	draw_rect(Rect2(0, water_top, beach_width, 120.0), COLOR_SHALLOW_WATER)
	draw_rect(Rect2(0, water_top + 45.0, beach_width, 75.0), COLOR_DEEP_WATER)

	# 5. Foam Edge (Waves cresting on sand)
	for x in range(0, int(beach_width), 16):
		var wave_y := water_top + sin(float(x) * 0.04) * 3.5
		draw_circle(Vector2(x, wave_y), 4.5, COLOR_FOAM)

	# 6. Scatter Coastal Pebbles
	for rock in rocks:
		draw_circle(rock["pos"] + Vector2(1, 1), rock["size"], Color(0.3, 0.28, 0.25, 0.4)) # shadow
		draw_circle(rock["pos"], rock["size"], rock["color"])

	# 7. Scatter Beach Shells
	for shell in shells:
		var p: Vector2 = shell["pos"]
		draw_circle(p, shell["size"], shell["color"])
		draw_arc(p, shell["size"], 0.0, PI, 6, shell["color"].darkened(0.2), 1.0)

