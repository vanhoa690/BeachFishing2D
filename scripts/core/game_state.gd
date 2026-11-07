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
var fish_inventory: Array[Dictionary] = []

var fish_count: int:
	get:
		return fish_inventory.size()

var master_bait_count: int = 0
var has_pro_rod: bool = false
var chest_storage: Array[Dictionary] = []

var sea_coins: int:
	get:
		return EconomyManager.sea_coins if Engine.has_singleton("EconomyManager") or is_instance_valid(EconomyManager) else 0
	set(value):
		if Engine.has_singleton("EconomyManager") or is_instance_valid(EconomyManager):
			EconomyManager.sea_coins = value


func add_coins(amount: int) -> void:
	if is_instance_valid(EconomyManager):
		EconomyManager.add_coins(amount)


func spend_coins(amount: int) -> bool:
	if is_instance_valid(EconomyManager):
		return EconomyManager.spend_coins(amount)
	return false


func add_fish_to_chest(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	chest_storage.append(entry)
	GameEvents.chest_storage_changed.emit(chest_storage)


func remove_fish_from_chest(index: int) -> Dictionary:
	if index < 0 or index >= chest_storage.size():
		return {}
	var item: Dictionary = chest_storage.pop_at(index)
	GameEvents.chest_storage_changed.emit(chest_storage)
	return item

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

	# Provide 1 starter caught fish in inventory for immediate Phase 3 rack testing
	if ResourceLoader.exists("res://data/fish/clownfish.tres"):
		var starter_fish: FishData = load("res://data/fish/clownfish.tres") as FishData
		if starter_fish:
			add_fish_to_inventory(starter_fish, 0.35)


func add_fish_to_inventory(fish: FishData, weight: float) -> Dictionary:
	if not fish:
		return {}
	var entry: Dictionary = {
		"fish_id": fish.id,
		"display_name": fish.display_name,
		"weight": weight,
		"texture_path": fish.texture.resource_path if fish.texture else "",
		"value": fish.calculate_value(weight),
		"timestamp": Time.get_unix_time_from_system()
	}
	fish_inventory.append(entry)
	GameEvents.fish_inventory_changed.emit(fish_inventory)
	return entry


func add_fish_dict_to_inventory(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	fish_inventory.append(entry)
	GameEvents.fish_inventory_changed.emit(fish_inventory)


func pop_first_fish() -> Dictionary:
	if fish_inventory.is_empty():
		return {}
	var item: Dictionary = fish_inventory.pop_front()
	GameEvents.fish_inventory_changed.emit(fish_inventory)
	return item


func remove_fish_by_index(index: int) -> Dictionary:
	if index < 0 or index >= fish_inventory.size():
		return {}
	var item: Dictionary = fish_inventory.pop_at(index)
	GameEvents.fish_inventory_changed.emit(fish_inventory)
	return item


func has_fish_in_inventory() -> bool:
	return not fish_inventory.is_empty()


func get_inventory_count() -> int:
	return fish_inventory.size()


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


## Serializes inventory, chest storage, and coin balances into a local dictionary for saving.
func save_state_to_dict() -> Dictionary:
	var coins_val: int = EconomyManager.sea_coins if (Engine.has_singleton("EconomyManager") or is_instance_valid(EconomyManager)) else 0
	return {
		"version": 1,
		"sea_coins": coins_val,
		"worms_count": worms_count,
		"master_bait_count": master_bait_count,
		"has_pro_rod": has_pro_rod,
		"total_catches": total_catches,
		"fish_inventory": fish_inventory.duplicate(true),
		"chest_storage": chest_storage.duplicate(true),
		"caught_fish_registry": caught_fish_registry.duplicate(true)
	}


## Deserializes inventory, chest storage, and coin balances from a saved dictionary.
func load_state_from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	if data.has("sea_coins"):
		if Engine.has_singleton("EconomyManager") or is_instance_valid(EconomyManager):
			EconomyManager.sea_coins = int(data["sea_coins"])

	if data.has("worms_count"):
		worms_count = int(data["worms_count"])

	if data.has("master_bait_count"):
		master_bait_count = int(data["master_bait_count"])

	if data.has("has_pro_rod"):
		has_pro_rod = bool(data["has_pro_rod"])

	if data.has("total_catches"):
		total_catches = int(data["total_catches"])

	if data.has("fish_inventory"):
		fish_inventory.clear()
		for item in data["fish_inventory"]:
			fish_inventory.append(item)
		GameEvents.fish_inventory_changed.emit(fish_inventory)

	if data.has("chest_storage"):
		chest_storage.clear()
		for item in data["chest_storage"]:
			chest_storage.append(item)
		GameEvents.chest_storage_changed.emit(chest_storage)

	if data.has("caught_fish_registry"):
		caught_fish_registry.clear()
		for entry in data["caught_fish_registry"]:
			caught_fish_registry.append(entry)

	return true
