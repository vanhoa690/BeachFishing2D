class_name BeachMain
extends Node2D
## Main World Controller for Coastal Beach in "Tide & Hook"
## Coordinates TileMapLayer environment, player, dig spot interactables, and celebrations.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/mechanics/floating_text.tscn")
const CATCH_POPUP_SCENE: PackedScene = preload("res://scenes/ui/catch_popup.tscn")
const SEAGULL_SCENE: PackedScene = preload("res://scenes/world/seagull.tscn")

const FISH_RESOURCES: Array[String] = [
	"res://data/fish/clownfish.tres",
	"res://data/fish/blue_tang.tres",
	"res://data/fish/sea_bass.tres",
	"res://data/fish/red_snapper.tres"
]

const MAP_WIDTH: int = 1600
const MAP_HEIGHT: int = 1024

@onready var player: PlayerCharacter = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
@onready var effects_layer: Node2D = $World/Effects

@onready var water_layer: TileMapLayer = $WorldMap/WaterLayer
@onready var shoreline_layer: TileMapLayer = $WorldMap/ShorelineLayer
@onready var ground_layer: TileMapLayer = $WorldMap/GroundLayer
@onready var decor_layer: TileMapLayer = $WorldMap/DecorLayer

var _seagull_timer: float = 0.0


func _ready() -> void:
	# Configure Camera boundaries to match coastal sandbox limits
	if camera:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = MAP_WIDTH
		camera.limit_bottom = MAP_HEIGHT

	# Connect gameplay events
	GameEvents.worm_dug.connect(_on_worm_dug)
	GameEvents.fish_caught.connect(_on_fish_caught)


func _process(delta: float) -> void:
	_seagull_timer += delta
	if _seagull_timer >= 6.0:
		_seagull_timer = 0.0
		var seagulls = get_tree().get_nodes_in_group("seagull")
		if seagulls.size() < 2 and SEAGULL_SCENE:
			var new_gull: Node2D = SEAGULL_SCENE.instantiate() as Node2D
			var from_left: bool = randf() > 0.5
			var spawn_x: float = 200.0 if from_left else 1500.0
			var spawn_y: float = randf_range(200.0, 700.0)
			new_gull.position = Vector2(spawn_x, spawn_y)
			$World.add_child(new_gull)


func _unhandled_input(event: InputEvent) -> void:
	# Quick test shortcut: Press [C] to test catch celebration popup with random fish
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_test_catch_random_fish()


func _on_worm_dug(amount: int, world_pos: Vector2) -> void:
	if not FLOATING_TEXT_SCENE:
		return
		
	var text_inst: FloatingText = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	text_inst.global_position = world_pos + Vector2(0, -14)
	var label_msg: String = "+%d Sand Worm%s!" % [amount, "s" if amount > 1 else ""]
	effects_layer.add_child(text_inst)
	text_inst.setup(label_msg, Color(1.0, 0.88, 0.42))


func _on_fish_caught(fish_data: FishData, weight: float) -> void:
	if not CATCH_POPUP_SCENE:
		return
	var popup: CatchPopup = CATCH_POPUP_SCENE.instantiate() as CatchPopup
	add_child(popup)
	popup.display_catch(fish_data, weight)


func _test_catch_random_fish() -> void:
	if FISH_RESOURCES.is_empty():
		return
	var chosen_path: String = FISH_RESOURCES.pick_random()
	var fish: FishData = load(chosen_path) as FishData
	if fish:
		GameEvents.fish_caught.emit(fish, -1.0)


func is_pos_diggable(world_pos: Vector2) -> bool:
	if not is_instance_valid(ground_layer):
		return false
	var map_coord := ground_layer.local_to_map(ground_layer.to_local(world_pos))
	var data := ground_layer.get_cell_tile_data(map_coord)
	if data and data.get_custom_data("is_diggable"):
		return true
	return false


func is_pos_water(world_pos: Vector2) -> bool:
	if not is_instance_valid(water_layer):
		return false
	var map_coord := water_layer.local_to_map(water_layer.to_local(world_pos))
	var data := water_layer.get_cell_tile_data(map_coord)
	if data and data.get_custom_data("is_water"):
		return true
	return false
