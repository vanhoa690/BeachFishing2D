extends Node
## Global Game State Singleton for "Tide & Hook"
## Tracks persistent player stats, inventory, active tools, and world progression.

enum ToolType {
	NONE = 0,
	SHOVEL = 1,
	FISHING_ROD = 2
}

const TOOL_NAMES: Dictionary = {
	ToolType.NONE: "Bare Hands",
	ToolType.SHOVEL: "Sand Shovel",
	ToolType.FISHING_ROD: "Bamboo Rod"
}

const TOOL_DESCRIPTIONS: Dictionary = {
	ToolType.NONE: "Use your hands to interact or inspect.",
	ToolType.SHOVEL: "Dig for juicy sand worms near coastal mounds.",
	ToolType.FISHING_ROD: "Cast your line into the azure sea."
}

var current_tool: ToolType = ToolType.NONE:
	set(value):
		if current_tool != value:
			current_tool = value
			GameEvents.tool_changed.emit(current_tool)

var worms_count: int = 1:
	set(value):
		worms_count = maxi(0, value)
		GameEvents.worms_count_changed.emit(worms_count)

var caught_fish_registry: Array[Dictionary] = []
var total_catches: int = 0

const REGISTERED_FISH_PATHS: Array[String] = [
	"res://data/fish/clownfish.tres",
	"res://data/fish/blue_tang.tres",
	"res://data/fish/sea_bass.tres",
	"res://data/fish/red_snapper.tres"
]


func _ready() -> void:
	# Start with Fishing Rod and 1 bait ready as requested
	current_tool = ToolType.FISHING_ROD
	worms_count = 1


func has_bait() -> bool:
	return worms_count > 0


func consume_bait() -> bool:
	return remove_worms(1)


func roll_random_fish() -> FishData:
	var pool: Array[FishData] = []
	var total_weight: float = 0.0

	for path in REGISTERED_FISH_PATHS:
		if ResourceLoader.exists(path):
			var fish: FishData = load(path) as FishData
			if fish:
				pool.append(fish)
				total_weight += fish.rarity_weight

	if pool.is_empty():
		return null

	var roll: float = randf_range(0.0, total_weight)
	var accum: float = 0.0
	for fish in pool:
		accum += fish.rarity_weight
		if roll <= accum:
			return fish

	return pool[0]


func set_tool(new_tool: ToolType) -> void:
	current_tool = new_tool


func cycle_tool(step: int = 1) -> void:
	var total_tools: int = ToolType.size()
	var next_val: int = (int(current_tool) + step) % total_tools
	if next_val < 0:
		next_val += total_tools
	current_tool = next_val as ToolType


func add_worms(amount: int) -> void:
	if amount > 0:
		worms_count += amount


func remove_worms(amount: int) -> bool:
	if worms_count >= amount:
		worms_count -= amount
		return true
	return false


func record_fish_catch(fish: FishData, weight: float) -> void:
	if not fish:
		return
	total_catches += 1
	var entry: Dictionary = {
		"id": fish.id,
		"name": fish.display_name,
		"weight": weight,
		"value": fish.calculate_value(weight),
		"timestamp": Time.get_unix_time_from_system()
	}
	caught_fish_registry.append(entry)


func get_fish_count() -> int:
	return caught_fish_registry.size()


func get_tool_name(tool: ToolType) -> String:
	return TOOL_NAMES.get(tool, "Unknown Tool")

